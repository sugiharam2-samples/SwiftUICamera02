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

class BaseMetalView: UIView, AVCaptureVideoDataOutputSampleBufferDelegate {
	private let metalLayer = CAMetalLayer()
	private let device = MTLCreateSystemDefaultDevice()!
	private lazy var commandQueue = device.makeCommandQueue()
	private let renderPassDescriptor = MTLRenderPassDescriptor()
	private lazy var renderPipelineState: MTLRenderPipelineState! = {
		guard let library = device.makeDefaultLibrary() else { return nil }
		let descriptor = MTLRenderPipelineDescriptor()
		descriptor.vertexFunction = library.makeFunction(name: "vertexShader")
		descriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
		descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
		return try? device.makeRenderPipelineState(descriptor: descriptor)
	}()
	private let captureSession = AVCaptureSession()

	let vertexData: [[Float]] = [
		// 0: positions
		[
			-1, 1, 0, 1,
			1, 1, 0, 1,
			-1, -1, 0, 1,
			1, -1, 0, 1,
		],
		// 1: texCoords
		[
			0, 0,
			0, 1,
			1, 0,
			1, 1,
		],
	]

	override func layoutSubviews() {
		super.layoutSubviews()
		_ = initCaptureSession
		metalLayer.frame = layer.frame
	}

	lazy var initCaptureSession: Void = {
		metalLayer.device = device
		layer.addSublayer(metalLayer)

		guard let captureDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
																   mediaType: .video,
																   position: .front).devices.first,
			  let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }

		let output = AVCaptureVideoDataOutput()
		output.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as [String : Any]
		output.setSampleBufferDelegate(self, queue: DispatchQueue.main)

		captureSession.addInput(input)
		captureSession.addOutput(output)
		captureSession.startRunning()
	}()

	func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
		CVPixelBufferLockBaseAddress(buffer, .readOnly)

		let width = CVPixelBufferGetWidth(buffer)
		let height = CVPixelBufferGetHeight(buffer)

		var textureCache: CVMetalTextureCache!
		CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
		var texture: CVMetalTexture!
		_ = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, buffer, nil, .bgra8Unorm, width, height, 0, &texture)

		guard let drawable = metalLayer.nextDrawable(),
			  let commandBuffer = commandQueue?.makeCommandBuffer() else { return }

		renderPassDescriptor.colorAttachments[0].texture = drawable.texture
		guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
		encoder.setRenderPipelineState(renderPipelineState)

		vertexData.enumerated().forEach { i, array in
			let size = array.count * MemoryLayout.size(ofValue: array[0])
			let buffer = device.makeBuffer(bytes: array, length: size)
			encoder.setVertexBuffer(buffer, offset: 0, index: i)
		}

		encoder.setFragmentTexture(CVMetalTextureGetTexture(texture), index: 0)
		encoder.drawPrimitives(type: .triangleStrip,
							   vertexStart: 0,
							   vertexCount: vertexData[0].count / 4)

		encoder.endEncoding()
		commandBuffer.present(drawable)
		commandBuffer.commit()

		CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
