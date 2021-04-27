//
//  ContentView.swift
//  SwiftUICamera02
//
//  Created by Mamoru Sugihara on 2021/04/27.
//

import SwiftUI
import AVFoundation
import MetalKit

struct ContentView: View {
    var body: some View {
		MetalView()
    }
}

struct MetalView: UIViewRepresentable {
	func makeUIView(context: Context) -> some UIView { BaseMetalView() }
	func updateUIView(_ uiView: UIViewType, context: Context) {}
}

class BaseMetalView: UIView {
	let device = MTLCreateSystemDefaultDevice()!

	private var commandQueue: MTLCommandQueue!
	private var renderPassDescriptor = MTLRenderPassDescriptor()
	private var renderPipelineState: MTLRenderPipelineState!
	private var metalLayer = CAMetalLayer()
	private var videoImage: MTLTexture?
	private var captureSession: AVCaptureSession!

	override func layoutSubviews() {
		super.layoutSubviews()
		_ = initCaptureSession
		metalLayer.frame = layer.frame
		draw()
	}

	lazy var initCaptureSession: Void = {
		metalLayer.device = device
		layer.addSublayer(metalLayer)

		commandQueue = device.makeCommandQueue()

		guard let library = device.makeDefaultLibrary() else { return }
		let descriptor = MTLRenderPipelineDescriptor()
		descriptor.vertexFunction = library.makeFunction(name: "vertexShader")
		descriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
		descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
		renderPipelineState = try! device.makeRenderPipelineState(descriptor: descriptor)

		guard let device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
															mediaType: .video,
															position: .unspecified)
				.devices.first(where: { $0.position == .front }),
			  let input = try? AVCaptureDeviceInput(device: device) else { return }
		let output = AVCaptureVideoDataOutput()
		output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String : Int(kCVPixelFormatType_32BGRA)]
		let queue = DispatchQueue(label: "myqueue", attributes: .concurrent)
		output.setSampleBufferDelegate(self, queue: queue)
		output.alwaysDiscardsLateVideoFrames = true

		captureSession = AVCaptureSession()
		captureSession.addInput(input)
		captureSession.addOutput(output)
		captureSession.startRunning()
	}()

	func draw() {
		guard let drawable = metalLayer.nextDrawable(),
			  let commandBuffer = commandQueue.makeCommandBuffer() else { return }

		renderPassDescriptor.colorAttachments[0].texture = drawable.texture
		let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!

		let positions: [Float] = [
			-1,  1, 0, 1,
			 1,  1, 0, 1,
			-1, -1, 0, 1,
			 1, -1, 0, 1,
		]
		let texCoords: [Float] = [
			0, 0,
			0, 1,
			1, 0,
			1, 1,
		]
		let sizePos = positions.count * MemoryLayout.size(ofValue: positions[0])
		let bufferPositions = device.makeBuffer(bytes: positions, length: sizePos)
		let sizeTex = texCoords.count * MemoryLayout.size(ofValue: texCoords[0])
		let bufferTexCoords = device.makeBuffer(bytes: texCoords, length: sizeTex)

		encoder.setRenderPipelineState(renderPipelineState)
		encoder.setVertexBuffer(bufferPositions, offset: 0, index: 0)
		encoder.setVertexBuffer(bufferTexCoords, offset: 0, index:1)
		encoder.setFragmentTexture(videoImage, index: 0)
		encoder.drawPrimitives(type: .triangleStrip,
							   vertexStart: 0,
							   vertexCount: positions.count / 4)

		encoder.endEncoding()
		commandBuffer.present(drawable)
		commandBuffer.commit()
	}
}

extension BaseMetalView: AVCaptureVideoDataOutputSampleBufferDelegate {
	func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		DispatchQueue.main.sync {
			if let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
				CVPixelBufferLockBaseAddress(buffer, .readOnly)
				let width = CVPixelBufferGetWidth(buffer)
				let height = CVPixelBufferGetHeight(buffer)

				var textureCache : CVMetalTextureCache?
				CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.device, nil, &textureCache)

				var imageTexture: CVMetalTexture?
				_ = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache!, buffer, nil, .bgra8Unorm, width, height, 0, &imageTexture)

				self.videoImage = CVMetalTextureGetTexture(imageTexture!)
				CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
				draw()
			}
		}
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
