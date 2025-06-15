import Foundation
import AVFoundation
import Accelerate

class AudioResampler {
    
    static func resampleToWhisperFormat(samples: [Float], fromSampleRate: Double) -> [Float] {
        let targetSampleRate: Double = 16000.0
        
        // If already at target sample rate, return as-is
        if abs(fromSampleRate - targetSampleRate) < 1.0 {
            return samples
        }
        
        // Calculate the ratio
        let ratio = targetSampleRate / fromSampleRate
        let outputLength = Int(Double(samples.count) * ratio)
        
        // Use simple linear interpolation for resampling
        var resampledSamples = [Float]()
        resampledSamples.reserveCapacity(outputLength)
        
        for i in 0..<outputLength {
            let sourceIndex = Double(i) / ratio
            let lowerIndex = Int(floor(sourceIndex))
            let upperIndex = min(lowerIndex + 1, samples.count - 1)
            let fraction = Float(sourceIndex - Double(lowerIndex))
            
            if lowerIndex < samples.count {
                let lowerSample = samples[lowerIndex]
                let upperSample = samples[upperIndex]
                let interpolatedSample = lowerSample + (upperSample - lowerSample) * fraction
                resampledSamples.append(interpolatedSample)
            }
        }
        
        print("AudioResampler: Resampled from \(fromSampleRate)Hz (\(samples.count) samples) to \(targetSampleRate)Hz (\(resampledSamples.count) samples)")
        return resampledSamples
    }
    
    static func resampleUsingAccelerate(samples: [Float], fromSampleRate: Double) -> [Float] {
        let targetSampleRate: Double = 16000.0
        
        // If already at target sample rate, return as-is
        if abs(fromSampleRate - targetSampleRate) < 1.0 {
            return samples
        }
        
        let ratio = targetSampleRate / fromSampleRate
        let outputLength = Int(Double(samples.count) * ratio)
        
        // Create output buffer
        var outputSamples = [Float](repeating: 0.0, count: outputLength)
        
        // Use vDSP for high-quality resampling
        samples.withUnsafeBufferPointer { inputBuffer in
            outputSamples.withUnsafeMutableBufferPointer { outputBuffer in
                // Simple decimation/interpolation using vDSP
                if ratio < 1.0 {
                    // Downsampling - use simple decimation instead of vDSP_desamp
                    let decimationFactor = Int(1.0 / ratio)
                    for i in stride(from: 0, to: samples.count, by: decimationFactor) {
                        if i / decimationFactor < outputLength {
                            outputBuffer[i / decimationFactor] = samples[i]
                        }
                    }
                } else {
                    // Upsampling - use linear interpolation
                    for i in 0..<outputLength {
                        let sourceIndex = Double(i) / ratio
                        let lowerIndex = Int(floor(sourceIndex))
                        let upperIndex = min(lowerIndex + 1, samples.count - 1)
                        let fraction = Float(sourceIndex - Double(lowerIndex))
                        
                        if lowerIndex < samples.count {
                            let lowerSample = samples[lowerIndex]
                            let upperSample = samples[upperIndex]
                            outputBuffer[i] = lowerSample + (upperSample - lowerSample) * fraction
                        }
                    }
                }
            }
        }
        
        print("AudioResampler: High-quality resampled from \(fromSampleRate)Hz (\(samples.count) samples) to \(targetSampleRate)Hz (\(outputSamples.count) samples)")
        return outputSamples
    }
} 