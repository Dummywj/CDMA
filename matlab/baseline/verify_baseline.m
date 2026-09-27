function verify_baseline()
% Verify bit conventions using independent arithmetic implementations.
cfg = init_baseline();
vectors = [zeros(172,1),ones(172,1),mod((0:171)',2), ...
    double(mod((0:171)'.^2+floor((0:171)'/3),2))];
poly = [1 1 1 1 0 0 0 1 0 0 1 1];
for k = 1:size(vectors,2)
    reg = ones(1,12);
    for bit = vectors(:,k).'
        feedback = xor(bit,reg(1));
        reg = xor([reg(2:end) 0],feedback & poly);
    end
    ref = double(reg(:));
    actual = crcGenerate(logical(vectors(:,k)),cfg.crc);
    assert(isequal(ref,double(actual(end-11:end))), 'CRC bit convention mismatch.');
end
% Encode directly from the documented octal taps, independently of trellis.
data = [vectors(:,4);zeros(8,1)];
g = [dec2bin(base2dec('753',8),9)-'0';dec2bin(base2dec('561',8),9)-'0'];
reg = zeros(1,9); ref = zeros(2*numel(data),1);
for k = 1:numel(data)
    reg = [data(k) reg(1:8)];
    ref(2*k-1:2*k) = mod(g*reg.',2);
end
assert(isequal(ref,convenc(data,cfg.trellis)),'Convolutional output ordering mismatch.');
[~,i,q] = short_pn();
% Removing the inserted zero must restore the recurrence across its wrap.
for entry = { {i,[15 10 8 7 6 2]}, {q,[15 12 11 10 9 5 4 3]} }
    e = entry{1}; bits = e{1}; lags = e{2}; raw = bits(1:end-1);
    for n = 1:numel(raw)
        assert(raw(n) == mod(sum(raw(mod(n-lags-1,numel(raw))+1)),2));
    end
end
assert(cfg.trafficWalsh.'*cfg.syncWalsh == 0);
assert(sum(cfg.trafficWalsh) == 0 && sum(cfg.syncWalsh) == 0);
u = baseline_step('SyncSource',0);
[ref,s] = convenc([u;u],cfg.trellis);
actual = baseline_step('SyncEncode',u);
assert(isequal(actual,ref(193:end)) && s>=0,'Sync state continuity mismatch.');
fprintf('Independent CRC, convolutional taps, PN recurrence, Walsh and sync-state checks passed.\n');
end
