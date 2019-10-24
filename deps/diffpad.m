function dX = diffpad(X, dim, n, padval, direction)
%DIFFPAD Differentiate keeping the array the same size via padding.
% Usage:
%   dX = diffpad(X)
%   dX = diffpad(X, dim, n, padval, direction)
% 
% Args:
%   X: numeric matrix
%   dim: dimension along which to differentiate (default: first non-singleton dimension)
%   n: number of derivatives (default: 1)
%   padval: value to pad with (default: 0)
%   direction: where to pad as 'pre' or 'post' (default: 'pre')
% 
% See also: diff, padarray, catpadarr

if nargin < 2 || isempty(dim); dim = find(size(X)>1,1); end
if nargin < 3 || isempty(n); n = 1; end
if nargin < 4 || isempty(padval); padval = 0; end
if nargin < 5 || isempty(direction); direction = 'pre'; end

dX = diff(X,n,dim);
padsz = zeros(1,ndims(X));
padsz(dim) = 1;
dX = padarray(dX,padsz,padval,direction);

end
