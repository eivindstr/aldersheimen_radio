% Include necessary libraries and setup parameters
run('soundParams.m');

% Setup audio capture
audioReader = audioDeviceReader('SamplesPerFrame', 2000, 'SampleRate', newFs);

% Setup PlutoSDR transmitter
tx = sdrtx('Pluto');
tx.CenterFrequency = fc;
tx.BasebandSampleRate = fs;
tx.Gain = 0;



% Process and transmit in a loop
disp('Starting transmission...');
while true
    % Capture audio data from mic
    audioData = audioReader(); 

    % Convert audio data to 16-bit int
    audioData = int16(audioData * 32767); % Scale to 16-bit range

    % Convert audio samples to bits
    audioBits = reshape(dec2bin(typecast(audioData(:), 'uint16'), 16).' - '0', 1, []);
    symbolIndices = bi2de(reshape(audioBits, log2(M), []).', 'left-msb');

    % Calculate the number of packets
    numPackets = ceil(length(symbolIndices) / dataLength);
    modulatedSymbols = [];

    for i = 1:numPackets
        % Insert preamble at a interval specified by dataLength
        startIdx = (i-1) * dataLength + 1;
        endIdx = min(i * dataLength, length(symbolIndices));
        packetData = symbolIndices(startIdx:endIdx);

        % Check if the current packet has enough data
        if length(packetData) < dataLength
            continue; % Skip the rest of the loop iteration if not enough, we can't demodulate dynamic packet length
        end


        % Prepend preamble to packetData
        packet = [barkerSequence, packetData.'];

        % Modulate the packet
        txSig = pskmod(packet, M, pi/M, 'gray');

        % Apply RRC Filter
        txSigFiltered = upfirdn(txSig, rrcFilter, sps);

        % Append to the overall modulated packets array
        modulatedSymbols = [modulatedSymbols; txSigFiltered.']; % Consider any required gap between packets
    end

    % Transmit the buffered signal
    tx(modulatedSymbols); % Continuously transmit the buffered signal
end
