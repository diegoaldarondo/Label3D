function F = computeFundamental(KL, KR, R, T)
    S = [ 0 -T(3) T(2); T(3) 0 -T(1); -T(2) T(1) 0];
    F = inv(KL)'*R*(R'*T)*inv(KR);
end
% function F = computeFundamental(K1, K2, R, t)
%     A = K1 * R' * t';
%     C = [0 -A(3) A(2); A(3) 0 -A(1); -A(2) A(1) 0];
%     F = inv(K2)' * R * K1' * C;
% end


    