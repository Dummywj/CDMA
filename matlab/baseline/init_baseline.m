function cfg = init_baseline()
% Initialize the floating-point model; retain deliberate caller overrides.
addpath(fileparts(mfilename('fullpath')));
if evalin('base', "exist('cfg','var')")
    cfg = evalin('base', 'cfg');
    if isstruct(cfg) && isfield(cfg, 'baselineVersion') && cfg.baselineVersion == 1
        return
    end
end
cfg.baselineVersion = 1;
cfg.chipRate = 1228800;
cfg.batchSeconds = 0.08;
cfg.chipsPerBatch = 98304;
cfg.payloadPerFrame = 172;
cfg.framesPerBatch = 4;
cfg.pilotAmplitude = 0.5;
cfg.syncAmplitude = 0.25;
cfg.trafficAmplitude = 1;
cfg.EbNoDb = 4;
cfg.noiseEnabled = true;
cfg.seed = 20260927;
cfg.trellis = poly2trellis(9, [753 561]);
cfg.crc = crcConfig('Polynomial', [12 11 10 9 8 4 1 0], ...
    'InitialConditions', 1, 'DirectMethod', true, 'FinalXOR', 0);
cfg.pn = repmat(short_pn(), 3, 1);
H = hadamard(64);
cfg.trafficWalsh = H(2,:).';
cfg.syncWalsh = H(33,:).';
cfg.trafficPermutation = bro(384, 6, 6);
cfg.syncPermutation = bro(128, 7, 1);
assignin('base', 'cfg', cfg);
end

function p = bro(N, m, J)
v = floor((0:N-1)'/J);
b = zeros(N,1);
for k = 1:m
    b = 2*b + mod(v,2);
    v = floor(v/2);
end
p = 2^m * mod((0:N-1)',J) + b + 1;
assert(isequal(sort(p), (1:N)'));
end
