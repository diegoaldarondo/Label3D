function lines = dragpoints(ax, x, y, varargin)
%can change the marker size or marker type to make it more visible.
%Currently is set to small points at a size of 2 so is not very visible.
lines = line(ax, x,y,'hittest','on','buttondownfcn',@clickmarker, varargin{:});

function clickmarker(src,ev)
set(ancestor(src,'figure'),'windowbuttonmotionfcn',{@dragmarker,src})
set(ancestor(src,'figure'),'windowbuttonupfcn',@stopdragging)

function dragmarker(fig,ev,src)

%get current axes and coords
h1=gca;
coords=get(h1,'currentpoint');

%get all x and y data 
% x=cat(2, [h1.Children.XData]);
% y=cat(2, [h1.Children.YData]);
% x=h1.Children.XData;
% y=h1.Children.YData;
x=src.XData;
y=src.YData;

%check which data point has the smallest distance to the dragged point
x_diff = abs(x-coords(1,1,1));
y_diff = abs(y-coords(1,2,1));
% keyboard;
[value index] = min(sqrt(x_diff.^2+y_diff.^2));

%create new x and y data and exchange coords for the dragged point
x_new=x;
y_new=y;
x_new(index)=coords(1,1,1);
y_new(index)=coords(1,2,1);
%update plot
set(src,'xdata',x_new,'ydata',y_new);




% for nLine = 1:numel(h1.Children)
%     if isequal(h1.Children(nLine), src)
%         continue;
%     end
%     x=h1.Children(nLine).XData;
%     y=h1.Children(nLine).YData;
%     x_diff=abs(x-coords(1,1,1));
%     y_diff=abs(y-coords(1,2,1));
%     if abs(min(sqrt(x_diff.^2+y_diff.^2)) - value) < .00001
%         dist = sqrt(x_diff.^2+y_diff.^2);
%         val = min(sqrt(x_diff.^2+y_diff.^2));
%         indices = dist == val;
%         x(indices)=coords(1,1,1);
%         y(indices)=coords(1,2,1);
%     end
%     set(h1.Children(nLine),'xdata',x,'ydata',y);
% end

function stopdragging(fig,ev)
set(fig,'windowbuttonmotionfcn','')
set(fig,'windowbuttonupfcn','')