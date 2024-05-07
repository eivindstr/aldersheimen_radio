
% Setup parameters
run('soundParams.m');
%load('fasit.mat')
% Setup PlutoSDR System object for receiving
rx = sdrrx('Pluto');
rx.CenterFrequency = fc;
rx.BasebandSampleRate = fs;
rx.SamplesPerFrame = numSamples;
rx.OutputDataType = 'double';

currentBarkerSequence = barkerSequence; %REMEMBER TO ALSO CHANGE LENGTH IN SOUNDPARAMS

%Define objects
    % Frequency compensation -------------------------------------------
    coarseSync = comm.CoarseFrequencyCompensator( ...  
        'Modulation','QPSK', ...
        'FrequencyResolution',10, ...
        'SampleRate',fs); %Fs*sps if signal is still oversampled
   
    % Symbol Synchronizer (Timing) --------------------------------------------
    symbolSync = comm.SymbolSynchronizer(...
        'TimingErrorDetector', 'Gardner (non-data-aided)', ...
        'DampingFactor', 0.7, ...
        'NormalizedLoopBandwidth', 0.01, ...
        'SamplesPerSymbol', sps); 
   
  
     % Fine frequency sync and FINE phase sync
     fineSync = comm.CarrierSynchronizer('DampingFactor', 0.7, ...
        'NormalizedLoopBandwidth', 0.01, ...
        'SamplesPerSymbol', 1, ...
        'Modulation', 'QPSK');



    % PSK modulate barkerSequence used in transmission
    barkerSymbols = pskmod(currentBarkerSequence, M, pi/M, 'gray');
    detector = comm.PreambleDetector(barkerSymbols.', 'Threshold', 19); 
    
    
% Main processing loop
keepRunning = true;
i=0;
numErrs = 0;
previousPhaseShift = 0;

% AUDIO PLAYBACK
player = audioDeviceWriter('SampleRate',newFs);
packetsToStore = 5; % Number of packets to store before playback
packetCounter = 0; % Counter to track stored packets
packetCounterTotal = 0;

% Initialize the buffer based on the expected size of rxDataDemod
demodBuffer = zeros(dataLength * packetsToStore, 1);
insertIndexDemod = 1; % Start index for inserting data into demodBuffer


while true
    rxData = rx();
    
    %scatterplot(rxData);
    
    
    % Concatenate overlapBuffer with the current samples (to detect packages at the end of previous buffer)
    currentBuffer = [overlapBuffer; rxData];


    % Filter the received signal. Remove a portion of the signal to account for the filter delay.
    rxSigFiltered = upfirdn(currentBuffer, rrcFilter,1,1);
    rxSigFiltered = rxSigFiltered(sps*span+1:end-(span*sps-1)); 
    
    % Frequency compensation -------------------------------------------
    [rxSigCoarse, freqEstimate] = coarseSync(rxSigFiltered);


    % Symbol Synchronizer (Timing) --------------------------------------------
    % Correct timing errors, downsamples by sps
    
    rxSigSync = symbolSync(rxSigCoarse);
    

    

    %----------------------------FRAME SYNC----------------------------------
    [rxSigFrames, packetCompletes,dataStartIdxs] = extractPackets(rxSigSync, detector, dataLength);

    % Iterate through each extracted packet
    for packetIdx = 1:length(rxSigFrames) 
        rxSigFrame = rxSigFrames{packetIdx}; % Extracted packet
        packetComplete = packetCompletes(packetIdx); % Completion status of the packet
        dataStartIdx = dataStartIdxs(packetIdx); % Starting index of the packet 
 
        if packetComplete % Denne kan kanskje fjernes
            % Only proceed with further processing if a complete packet was extracted

            %----------------------------PHASE CORRECTION-------------------
            [rxSigPhaseCorrected, estPhaseShift, estPhaseShiftDeg] = estimatePhaseOffset(rxSigFrame, currentBarkerSequence, M, rxSigSync, dataStartIdx);
            % Fine frequency sync and FINE phase sync
            
            rxSigFine = fineSync(rxSigPhaseCorrected);
            
            % Demodulate
            rxDataDemod = pskdemod(rxSigFine, M, pi/M, 'gray');
            
            
            % Append demodulated data to the storage vector
            %allDemodulatedPackets(insertIndex:(insertIndex + dataLength - 1)) = rxDataDemod;
            %insertIndex = insertIndex + dataLength; % Update the insertIndex
            % Assuming 'data' is the originally transmitted data you're comparing against, and 'numErrs' is initialized earlier
            numErrs =  numErrs + symerr(berPacket, rxDataDemod);
            
            % Calculate the new insert indices for the demodulated data
            startIdx = insertIndexDemod;
            endIdx = insertIndexDemod + dataLength - 1;

            % Update the buffer with the new demodulated data
            demodBuffer(startIdx:endIdx) = rxDataDemod;

            % Update the insert index for the next batch of data
            insertIndexDemod = endIdx + 1;
            packetCounter = packetCounter + 1;
            packetCounterTotal = packetCounterTotal + 1;

            % Check if the buffer is full 
            if packetCounter == packetsToStore
                
                %16 BIT CONVERTER
                receivedBits = reshape(de2bi(demodBuffer, log2(M), 'left-msb').', 1, []);
                receivedAudio = typecast(uint16(bin2dec(reshape(char(receivedBits + '0'), 16, []).')), 'int16');
                normalizedAudio = (double(receivedAudio)) / 32767; % Normalize for playback
                
                %8 BIT
                %receivedBits = reshape(de2bi(demodBuffer, log2(M), 'left-msb').', 1, []);
                %receivedAudio8Bit = typecast(uint8(bin2dec(reshape(char(receivedBits + '0'), 8, []).')), 'int8');
                %receivedAudio8Bit = uint8(bin2dec(reshape(char(receivedBits + '0'), 8, []).'));
                %normalizedAudio = (double(receivedAudio8Bit)) / 127;
                
                %receivedBits = reshape(de2bi(demodBuffer, log2(M), 'left-msb').', 1, []);
                %receivedAudio8Bit = uint8(bin2dec(reshape(char(receivedBits + '0'), 8, []).'));
                %normalizedAudio = double(receivedAudio8Bit) / 127.5 -1;
                % Play buffer
                player(normalizedAudio);  

                % Reset 
                demodBuffer = zeros(dataLength * packetsToStore, 1);
                packetCounter = 0;
                insertIndexDemod = 1;

            end
        end  
    end
 
    % Update overlapBuffer with the last part of rxData for the next iteration
    overlapBuffer = rxData(end-overlapSize+1:end);
    i = i+1;
    release(coarseSync);
    release(symbolSync);
    release(fineSync);
end

%scatterplot(rxData);
%scatterplot(rxSigFiltered);
%scatterplot(rxSigCoarse);
%scatterplot(rxSigSync);
%scatterplot(rxSigFrame);
%scatterplot(rxSigPhaseCorrected);
%scatterplot(rxSigFine);

%eyediagram(rxSigCoarse,2);
%eyediagram(rxSigSync,2);
%eyediagram(rxSigFrame,2);
%eyediagram(rxSigPhaseCorrected,2);
%eyediagram(rxSigFine,2);

% Release the System objects
release(rx);

