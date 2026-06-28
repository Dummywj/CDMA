%% Chapter A: QPSK over AWGN BER simulation using MATLAB toolbox functions
% Link: random bits -> QPSK modulation -> AWGN channel -> QPSK demodulation -> BER
% Requirement: Communications Toolbox.

clear; clc; close all;

%% 1. Simulation parameters
rng(2026);

nBits = 1e6;
ebN0dBList = 0:1:10;
modOrder = 4;                        % QPSK / 4-QAM
bitsPerSymbol = log2(modOrder);

if exist('qammod', 'file') == 0 || exist('qamdemod', 'file') == 0 || exist('awgn', 'file') == 0
    error('This script requires MATLAB Communications Toolbox.');
end

if mod(nBits, bitsPerSymbol) ~= 0
    error('nBits must be divisible by log2(modOrder).');
end

scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    outputDir = pwd;
else
    outputDir = fileparts(scriptPath);
end

%% 2. Generate random bits and modulate by QPSK
txBits = randi([0 1], nBits, 1);

txSymbols = qammod(txBits, modOrder, ...
    'InputType', 'bit', ...
    'UnitAveragePower', true);

averageSymbolEnergy = mean(abs(txSymbols).^2);
fprintf('Average QPSK symbol energy Es = %.6f\n', averageSymbolEnergy);

%% 3. Pass through AWGN and calculate BER
berSim = zeros(size(ebN0dBList));
bitErrors = zeros(size(ebN0dBList));

for idx = 1:numel(ebN0dBList)
    ebN0dB = ebN0dBList(idx);

    % awgn() accepts SNR per complex symbol sample. For uncoded QPSK:
    % Es/N0(dB) = Eb/N0(dB) + 10*log10(bitsPerSymbol).
    esN0dB = ebN0dB + 10 * log10(bitsPerSymbol);

    rxSymbols = awgn(txSymbols, esN0dB, 'measured');

    rxBits = qamdemod(rxSymbols, modOrder, ...
        'OutputType', 'bit', ...
        'UnitAveragePower', true);

    bitErrors(idx) = sum(txBits ~= rxBits);
    berSim(idx) = bitErrors(idx) / nBits;

    fprintf('Eb/N0 = %2d dB, bit errors = %6d, BER = %.6e\n', ...
        ebN0dB, bitErrors(idx), berSim(idx));
end

%% 4. Theoretical BER and result table
if exist('berawgn', 'file') ~= 0
    berTheory = berawgn(ebN0dBList, 'qam', modOrder);
else
    ebN0Linear = 10.^(ebN0dBList / 10);
    berTheory = 0.5 * erfc(sqrt(ebN0Linear));
end

resultTable = table(ebN0dBList(:), bitErrors(:), berSim(:), berTheory(:), ...
    'VariableNames', {'EbN0_dB', 'BitErrors', 'BER_Simulation', 'BER_Theory'});

disp(resultTable);

%% 5. Plot BER curve
figure('Name', 'Chapter A BER Curve - Toolbox Version');
semilogy(ebN0dBList, berSim, 'o-', 'LineWidth', 1.5); hold on;
semilogy(ebN0dBList, berTheory, 's--', 'LineWidth', 1.5);
grid on;
xlabel('Eb/N0 (dB)');
ylabel('BER');
title('QPSK over AWGN: Toolbox Simulation vs Theory');
legend('Simulation', 'Theory', 'Location', 'southwest');
ylim([1e-6 1]);

berFigurePath = fullfile(outputDir, 'ber_curve_toolbox.png');
saveas(gcf, berFigurePath);

%% 6. Plot constellation examples
constellationEbN0dB = [0, 8];
nConstellationSamples = min(5000, numel(txSymbols));
idealSymbols = qammod((0:modOrder-1).', modOrder, 'UnitAveragePower', true);

for idx = 1:numel(constellationEbN0dB)
    ebN0dB = constellationEbN0dB(idx);
    esN0dB = ebN0dB + 10 * log10(bitsPerSymbol);
    rxSymbolsForPlot = awgn(txSymbols(1:nConstellationSamples), esN0dB, 'measured');

    figure('Name', sprintf('Chapter A QPSK Constellation Toolbox %d dB', ebN0dB));
    plot(real(rxSymbolsForPlot), imag(rxSymbolsForPlot), '.', 'MarkerSize', 5); hold on;
    plot(real(idealSymbols), imag(idealSymbols), 'rx', 'LineWidth', 2, 'MarkerSize', 10);
    grid on; axis equal;
    xlim([-2 2]); ylim([-2 2]);
    xlabel('In-phase');
    ylabel('Quadrature');
    title(sprintf('Received QPSK Constellation, Eb/N0 = %d dB', ebN0dB));

    constellationFigurePath = fullfile(outputDir, sprintf('constellation_toolbox_%ddB.png', ebN0dB));
    saveas(gcf, constellationFigurePath);
end

%% 7. Save simulation data
dataPath = fullfile(outputDir, 'results_toolbox.mat');
save(dataPath, 'nBits', 'ebN0dBList', 'bitErrors', 'berSim', 'berTheory', ...
    'averageSymbolEnergy', 'resultTable');

fprintf('\nSaved BER curve to: %s\n', berFigurePath);
fprintf('Saved simulation data to: %s\n', dataPath);
