function verify_baseline()
% Verify bit conventions using independent arithmetic implementations.
cfg = init_baseline();
vectors = [zeros(192,1),ones(192,1),mod((0:191)',2), ...
    double(mod((0:191)'.^2+floor((0:191)'/3),2))];
% Encode directly from the documented octal taps, independently of trellis.
data = vectors(:,4);
g = [dec2bin(base2dec('753',8),9)-'0';dec2bin(base2dec('561',8),9)-'0'];
reg = zeros(1,9); ref = zeros(2*numel(data),1);
for k = 1:numel(data)
    reg = [data(k) reg(1:8)];
    ref(2*k-1:2*k) = mod(g*reg.',2);
end
assert(isequal(ref,convenc(data,cfg.trellis)),'Convolutional output ordering mismatch.');
% No CRC or tail insertion; nonzero final states must decode correctly.
source = vectors(:);
packed = baseline_step('FramePack',source);
assert(isequal(source,packed) && numel(packed)==768);
encoded = baseline_step('ConvEncode',packed);
assert(numel(encoded)==1536);
decoded = baseline_step('Viterbi',1-2*encoded);
assert(isequal(decoded,source), 'Unterminated frame decoding failed.');
assert(isequal(baseline_step('PayloadExtract',decoded),source));
[~, finalState] = convenc(vectors(:,2),cfg.trellis);
assert(finalState ~= 0, 'Test must include a nonzero encoder final state.');
assert(baseline_step('BatchErrors',[source;source])==0);
received = source; received(end)=1-received(end);
assert(baseline_step('BatchErrors',[source;received])==1/768);
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
[ref,s] = convenc([u;u;u],cfg.trellis);
actual = baseline_step('SyncEncode',u);
assert(isequal(actual,ref(193:384)) && isequal(actual,ref(385:576)) && s>=0, ...
    'Repeated sync pattern must remain continuous across batch boundaries.');
fprintf('192-bit framing, unterminated decoding, BER counting, taps, PN, Walsh and sync-state checks passed.\n');
end
