%% Chapter A: QPSK over AWGN BER simulation
% Link: random bits -> QPSK modulation -> AWGN channel -> QPSK demodulation -> BER
% This script uses only basic MATLAB functions. No Communications Toolbox is required.

clear; clc; close all;

%% 1. Simulation parameters
rng(2026);

nBits = 1e6;                 % Number of transmitted bits. Keep it even for QPSK.
ebN0dBList = 0:1:10;         % Eb/N0 sweep in dB.
bitsPerSymbol = 2;           % QPSK carries 2 bits per symbol.

if mod(nBits, bitsPerSymbol) ~= 0
    error('nBits must be an even number for QPSK modulation.');
end

scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    outputDir = pwd;
else
    outputDir = fileparts(scriptPath);
end

%% 2. Generate random bits and QPSK symbols
txBits = randi([0 1], nBits, 1);
txSymbols = qpskModulate(txBits);

% The mapper normalizes the average QPSK symbol energy to Es = 1.
averageSymbolEnergy = mean(abs(txSymbols).^2);
fprintf('Average QPSK symbol energy Es = %.6f\n', averageSymbolEnergy);

%% 3. BER simulation over AWGN channel
berSim = zeros(size(ebN0dBList));
bitErrors = zeros(size(ebN0dBList));

for idx = 1:numel(ebN0dBList)
    ebN0dB = ebN0dBList(idx);

    rxSymbols = awgnChannel(txSymbols, ebN0dB, bitsPerSymbol);
    rxBits = qpskDemodulate(rxSymbols);

    bitErrors(idx) = sum(txBits ~= rxBits);
    berSim(idx) = bitErrors(idx) / nBits;

    fprintf('Eb/N0 = %2d dB, bit errors = %6d, BER = %.6e\n', ...
        ebN0dB, bitErrors(idx), berSim(idx));
end

%% 4. Theoretical BER for Gray-coded QPSK in AWGN
ebN0Linear = 10.^(ebN0dBList / 10);
berTheory = 0.5 * erfc(sqrt(ebN0Linear));

resultTable = table(ebN0dBList(:), bitErrors(:), berSim(:), berTheory(:), ...
    'VariableNames', {'EbN0_dB', 'BitErrors', 'BER_Simulation', 'BER_Theory'});

disp(resultTable);

%% 5. Plot BER curve
figure('Name', 'Chapter A BER Curve');
semilogy(ebN0dBList, berSim, 'o-', 'LineWidth', 1.5); hold on;
semilogy(ebN0dBList, berTheory, 's--', 'LineWidth', 1.5);
grid on;
xlabel('Eb/N0 (dB)');
ylabel('BER');
title('QPSK over AWGN: Simulation vs Theory');
legend('Simulation', 'Theory', 'Location', 'southwest');
ylim([1e-6 1]);

berFigurePath = fullfile(outputDir, 'ber_curve.png');
saveas(gcf, berFigurePath);

%% 6. Plot constellation examples
constellationEbN0dB = [0, 8];
nConstellationSamples = min(5000, numel(txSymbols));
idealSymbols = qpskModulate([0; 0; 0; 1; 1; 1; 1; 0]);

for idx = 1:numel(constellationEbN0dB)
    ebN0dB = constellationEbN0dB(idx);
    rxSymbolsForPlot = awgnChannel(txSymbols(1:nConstellationSamples), ebN0dB, bitsPerSymbol);

    figure('Name', sprintf('Chapter A QPSK Constellation %d dB', ebN0dB));
    plot(real(rxSymbolsForPlot), imag(rxSymbolsForPlot), '.', 'MarkerSize', 5); hold on;
    plot(real(idealSymbols), imag(idealSymbols), 'rx', 'LineWidth', 2, 'MarkerSize', 10);
    grid on; axis equal;
    xlim([-2 2]); ylim([-2 2]);
    xlabel('In-phase');
    ylabel('Quadrature');
    title(sprintf('Received QPSK Constellation, Eb/N0 = %d dB', ebN0dB));

    constellationFigurePath = fullfile(outputDir, sprintf('constellation_%ddB.png', ebN0dB));
    saveas(gcf, constellationFigurePath);
end

%% 7. Save simulation data
dataPath = fullfile(outputDir, 'results.mat');
save(dataPath, 'nBits', 'ebN0dBList', 'bitErrors', 'berSim', 'berTheory', ...
    'averageSymbolEnergy', 'resultTable');

fprintf('\nSaved BER curve to: %s\n', berFigurePath);
fprintf('Saved simulation data to: %s\n', dataPath);

%% Local functions
function symbols = qpskModulate(bits)
    bits = bits(:);

    if mod(numel(bits), 2) ~= 0
        error('The number of input bits must be even.');
    end

    % Bit pair [b0 b1] mapping:
    % 00 -> ( 1 + j)/sqrt(2)
    % 01 -> (-1 + j)/sqrt(2)
    % 11 -> (-1 - j)/sqrt(2)
    % 10 -> ( 1 - j)/sqrt(2)
    b0 = bits(1:2:end);
    b1 = bits(2:2:end);

    inPhase = 1 - 2 * b1;
    quadrature = 1 - 2 * b0;

    symbols = (inPhase + 1j * quadrature) / sqrt(2);
end

function rxSymbols = awgnChannel(txSymbols, ebN0dB, bitsPerSymbol)
    ebN0Linear = 10^(ebN0dB / 10);

    % QPSK symbols are normalized to Es = 1, so Eb = Es / 2.
    symbolEnergy = mean(abs(txSymbols).^2);
    bitEnergy = symbolEnergy / bitsPerSymbol;
    n0 = bitEnergy / ebN0Linear;

    noise = sqrt(n0 / 2) * (randn(size(txSymbols)) + 1j * randn(size(txSymbols)));
    rxSymbols = txSymbols + noise;
end

function bits = qpskDemodulate(symbols)
    symbols = symbols(:);
    bits = zeros(2 * numel(symbols), 1);

    % Reverse of the qpskModulate mapping.
    bits(1:2:end) = imag(symbols) < 0;
    bits(2:2:end) = real(symbols) < 0;
end
