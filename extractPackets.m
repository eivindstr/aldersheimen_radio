function [rxSigFrames, packetCompletes, dataStartIdxs] = extractPackets(inputSignal, detector, dataLength)

    rxSigFrames = {};
    packetCompletes = [];
    dataStartIdxs = [];
  
   
    % Detect new packets in the remaining inputSignal
    idx = detector(inputSignal)
    
    lastDataStartIdx = 0; % Track start index of last detected packet.

    
    
    for i = 1:length(idx)
        dataStartIdx = idx(i) + 1;

        if (dataStartIdx - lastDataStartIdx) < 750
            continue; % Skip the preamble if it is too close to a different one
        end

        if (dataStartIdx + dataLength - 1) <= length(inputSignal)
            % Packet can be fully extracted from the current buffer
            lastDataStartIdx = dataStartIdx;
            rxSigFrame = inputSignal(dataStartIdx:dataStartIdx + dataLength -1);
            rxSigFrames{end+1} = rxSigFrame;
            packetCompletes(end+1) = true;
            dataStartIdxs(end+1) = dataStartIdx;
        else
 
            break; % if it can't be extracted from current buffer, break loop
        end 
    end

end
