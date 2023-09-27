//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate

class AudioModel {
    
    //Properties
    private var BUFFER_SIZE:Int
    // thse properties are for interfaceing with the API
    // the user can access these arrays at any time and plot them if they like
    var timeData:[Float]
    var fftData:[Float]
    //new properties for the 20-length array
    var shortData:[Float]
    
    
    // Public Method
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        //initialize the 20-length array
        shortData = Array.init(repeating: 0.0, count: 20)
    }
    
    // public function for starting processing of microphone data
    func startMicrophoneProcessing(withFps:Double){
        // setup the microphone to copy to circualr buffer
        if let manager = self.audioManager{
            manager.inputBlock = self.handleMicrophone
            
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            Timer.scheduledTimer(withTimeInterval: 1.0/withFps, repeats: true) { _ in
                self.runEveryInterval()
            }
            
        }
    }
    
    func calculateMaximaFromFFT() {
        // calculate the size of each window
        let windowSize = fftData.count / 20

        // looping the FFT magnitude array
        for i in 0..<20 {
            let start = i * windowSize
            let end = start + windowSize
            
            // get the data of each window
            let windowData = fftData[start..<end]
            
            // find the maximum data
            if let maxVal = windowData.max() {
                // save the maximum data to the new array
                shortData[i] = maxVal
            }
        }
    }

    private var isPlaying: Bool = false
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        if let manager = self.audioManager, !isPlaying {
            manager.play()
            isPlaying = true
            print("start")
        }
    }
    
    //pause the audio object when leaving the view controller
    func pause() {
        if let manager = self.audioManager, isPlaying {
            manager.pause()
            isPlaying = false
            print("pause")
        }
    }
    
    func wasPlaying() -> Bool {
        return isPlaying
    }
    
   // toggle playing
    func togglePlaying(){
        if let manager = self.audioManager ,
           let reader = self.fileReader {
            if manager.playing{
                //pause audio processing
                manager.pause()
                //stop buffering the song
                reader.pause()
            }
            else{
                //start both
                manager.play()
                reader.play()
            }
        }
    }
    func playmusic() {
        if let manager = self.audioManager,
           let reader = self.fileReader, !isPlaying {
            manager.play()
            reader.play()
            isPlaying = true
            print("start")
        }}
    func pausemusic() {
        if let manager = self.audioManager,
           let reader = self.fileReader, !isPlaying {
            manager.pause()
            reader.pause()
            isPlaying = true
            print("start")
            
        }
    }
            func setVolumne(val:Float){
                self.volume = val
            }
    // play from a file reder file
    func startProcesingAudilFileForPlayback(){
        //set the output block to read from and play the audio file
        if let manager = self.audioManager,
           let fileReader = self.fileReader{
            manager.outputBlock = self.handleSpeakerQueryWithAudioFile
            fileReader.play()
            
        }
    }
    
    //==========================================
    // MARK: Private Properties
    private var volume: Float = 1.0 // internal storage for volume
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    // find song in the main bundle
    private lazy var fileReader:AudioFileReader? = {
        if let url = Bundle.main.url(forResource: "satisfaction", withExtension: "mp3"){
            var tmpFileReader: AudioFileReader? = AudioFileReader.init(audioFileURL: url, samplingRate: Float(audioManager!.samplingRate), numChannels: audioManager!.numOutputChannels)
            tmpFileReader!.currentTime = 0.0 // start from time zero!
            print("Audil file successfully loaded for \(url)")
            return tmpFileReader
        }else{
            print("can not initialize audio input file")
            return nil
        }
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    //==========================================
    // MARK: Private Methods
    // NONE for this model
    
    //==========================================
    // Model Call Back Method
    private func runEveryInterval(){
        if inputBuffer != nil {
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData,
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData)
            
            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            // the user can now use these variables however they like
            
        }
    }
    
    //==========================================
    // Audiocard Call Back
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    //handleSpeaker
    private func handleSpeakerQueryWithAudioFile(data:Optional<UnsafeMutablePointer<Float>>, numFrams:UInt32, numChannels:UInt32){
        if let file = self.fileReader{
            if let arrayData = data{
                //read from file, loading into data
                file.retrieveFreshAudio(arrayData, numFrames: numFrams, numChannels: numChannels)
                vDSP_vsmul(arrayData, 1, &(self.volume), arrayData, 1, vDSP_Length(numFrams*numChannels))
                //convert audio data to swift array
                let musicdata = Array(UnsafeBufferPointer(start: arrayData, count: Int(numFrams*numChannels)))
                for i in 0..<musicdata.count {
                    timeData[i] = musicdata[i]
                
                }
                fftHelper!.performForwardFFT(withData: &timeData,
                                             andCopydBMagnitudeToBuffer: &fftData)
            }}
    }
}
