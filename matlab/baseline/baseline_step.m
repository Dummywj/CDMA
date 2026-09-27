function y = baseline_step(stage, u)
% Implement visible top-level stages of the ideal-sync CDMA baseline.
cfg = evalin('base', 'cfg');
u = u(:);
switch stage
    case 'TrafficSource'
        batch = round(real(u(1))/cfg.batchSeconds);
        stream = RandStream('mt19937ar', 'Seed', cfg.seed + batch);
        y = double(rand(stream, 768, 1) >= 0.5);
    case 'FramePack'
        % The current teaching baseline treats all 192 bits as payload.
        y = u;
    case 'ConvEncode'
        data = reshape(u,192,4);
        encoded = zeros(384,4);
        for k = 1:4
            encoded(:,k) = convenc(data(:,k),cfg.trellis);
        end
        y = encoded(:);
    case 'Interleave'
        data = reshape(u,384,4);
        data = data(cfg.trafficPermutation,:);
        y = data(:);
    case 'TrafficWalsh'
        y = cfg.trafficAmplitude * kron(1-2*u,cfg.trafficWalsh);
    case 'SyncSource'
        % A deterministic PHY test pattern, not a Layer-3 Sync Message.
        y = double(mod((0:95)' + floor((0:95)'/7), 2));
    case 'SyncEncode'
        % A cyclic convolutional state keeps the repeated pattern continuous.
        [~, state] = convenc(u,cfg.trellis);
        y = convenc(u,cfg.trellis,state);
    case 'SyncRepeatInterleave'
        data = reshape(repelem(u,2),128,3);
        data = data(cfg.syncPermutation,:);
        y = data(:);
    case 'SyncWalsh'
        % 4 Walsh periods per 4.8-ksymbol/s sync modulation symbol.
        y = cfg.syncAmplitude * kron(repelem(1-2*u,4),cfg.syncWalsh);
    case 'PilotWalsh'
        y = real(u(1))*ones(cfg.chipsPerBatch,1);
    case 'IQSpread'
        y = u .* cfg.pn;
    case 'AWGN'
        batch = round(real(u(end))/cfg.batchSeconds);
        y = u(1:end-1);
        if cfg.noiseEnabled
            % Eb refers to traffic energy per 192-bit baseline payload.
            variance = cfg.trafficAmplitude^2 * cfg.chipRate / ...
                (192/0.02) / 10^(cfg.EbNoDb/10);
            stream = RandStream('mt19937ar','Seed',cfg.seed+100000+batch);
            y = y + sqrt(variance/2) * complex( ...
                randn(stream,numel(y),1),randn(stream,numel(y),1));
        end
    case 'IQDespread'
        y = real(u .* conj(cfg.pn));
    case 'TrafficDespread'
        y = (cfg.trafficWalsh.' * reshape(u,64,[])).' / ...
            (64*cfg.trafficAmplitude);
    case 'Deinterleave'
        data = reshape(u,384,4);
        restored = zeros(size(data));
        restored(cfg.trafficPermutation,:) = data;
        y = restored(:);
    case 'Viterbi'
        data = reshape(u,384,4);
        decoded = zeros(192,4);
        for k = 1:4
            decoded(:,k) = vitdec(data(:,k), cfg.trellis, 40, 'trunc', 'unquant');
        end
        y = decoded(:);
    case 'PayloadExtract'
        y = u;
    case 'BatchErrors'
        n = numel(u)/2;
        y = nnz(u(1:n) ~= u(n+1:end))/n;
    otherwise
        error('baseline:UnknownStage','Unknown stage: %s',stage);
end
y = double(y(:));
end
