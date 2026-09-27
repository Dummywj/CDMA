function [code, iBits, qBits] = short_pn()
% Generate one IS-95/SR1 short-PN period at zero pilot offset.
% Recurrences and epoch: IS-2000-2-A 3.1.3.1.13.1 and 3.1.3.2.1.
iBits = make_sequence([15 10 8 7 6 2]);
qBits = make_sequence([15 12 11 10 9 5 4 3]);
code = complex(1 - 2*iBits, 1 - 2*qBits) / sqrt(2);
end

function bits = make_sequence(lags)
raw = ones(32767, 1);
for n = 16:32767
    raw(n) = mod(sum(raw(n-lags)), 2);
end
% Find the unique run of fourteen zeros and insert the fifteenth zero.
ends = find(conv(double(raw == 0), ones(14,1), 'valid') == 14) + 13;
assert(isscalar(ends), 'Expected exactly one fourteen-zero run.');
k = ends(1);
extended = [raw(1:k); 0; raw(k+1:end)];
% Epoch is the chip immediately after the fifteen-zero run.
bits = [extended(k+2:end); extended(1:k+1)];
assert(numel(bits) == 32768 && sum(bits) == 16384);
assert(bits(1) == 1 && all(bits(end-14:end) == 0));
end
