function varargout = chartGallery()
%CHARTGALLERY Launch the chart gallery.
% 
% Copyright 2018 The MathWorks, Inc.

% Launch the application.
GL = GalleryLauncher;

% Return the figure as an output argument, if requested.
if nargout
    varargout{1} = GL.Figure;
end % if

end % chartGallery