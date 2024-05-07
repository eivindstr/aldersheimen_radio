% Load the audio file
%[audioDataOriginal, fss] = audioread('CantinaBand3.wav');
fs = 1050624;           % Sample rate in Hz
fc = 1.7975e9;      % Center frequency in Hz (DO NOT USE ILLEGAL BANDS)


% mono conversion if needed
%if size(audioDataOriginal, 2) == 2
%    audioData = mean(audioDataOriginal, 2);
%else
%    audioData = audioDataOriginal;
%end

% Desired sampling rate
newFs = 16000;

% Resample the audio data
%audioDataResampled = resample(audioData, newFs, fss);
%sound(audioDataResampled, 16000);

% Modulate signal M-PSK 
M = 4;

% Barker Code sequence
barkerCode = [1, 1, 1, 1, 1, -1, -1, 1, 1, -1, 1, -1, 1]; % Barker code length 13
barkerCodeMapped = (barkerCode + 1)/2; % Mapping [-1, 1] to [0, 1] for QPSK
barkerCodeMapped2 = barkerCodeMapped+2;
barkerSequence = [barkerCodeMapped, barkerCodeMapped2];
newBarkerSequence = [3,3,2,1,2,2,3,3,3,0,3,1,1];


% RRC Filter parameters
rolloff = 0.5;  % Roll-off factor
span = 12;      % Filter span in symbols
sps = 8;        % Samples per symbol

% Create RRC Filters
rrcFilter = rcosdesign(rolloff, span, sps);



% Packet parameters
barkerLength = 26;
dataLength = 1000; % Number of symbols per packet
numSamples =10*(dataLength+barkerLength)*sps; % Number of samples per frame (MUST BE AT LEAST 2 x PACKET LENGTH)

overlapSize = dataLength + barkerLength - 1; % Define overlap size based on your preamble length and expected signal characteristics
overlapBuffer = zeros(overlapSize, 1); % Buffer to store the last part of the previous buffer for overlap

load('berPacket.mat', 'berPacket');

