classdef ValueAtRisk < Chart
    %VALUEATRISK Chart displaying the distribution of a return series
    %together with value at risk metrics and a non-parametric fit.
    %
    % Copyright 2018 The MathWorks, Inc.
    
    properties ( Hidden, Constant )
        % Product dependencies.
        Dependencies = {'MATLAB', ...
            'Statistics and Machine Learning Toolbox'};
    end % properties ( Hidden, Constant )
    
    % Public interface properties.
    properties ( Dependent )
        % Underlying data for the chart.
        Data
        % Value-at-risk level.
        VaRLevel
        % Axes x-label.
        XLabel
        % Axes y-label.
        YLabel
        % Axes title.
        Title
        % Legend text.
        LegendText
        % Legend font size.
        LegendFontSize
        % Legend location.
        LegendLocation
        % Grid display.
        Grid
        % Line style of the probability density function plot.
        DensityStyle
        % Line width of the probability density function plot.
        DensityWidth
        % Color of the probability density function plot.
        DensityColor
        % Histogram bar face transparency.
        FaceAlpha
        % Histogram bar face color.
        FaceColor
    end % properties (Dependent)
    
    % Private, internal graphics properties.
    properties (Access = private)
        % Histogram.
        Histogram
        % Distribution fit.
        DistributionFit
        % Density curve.
        Density
        % Vertical VaR line plot.
        VaRLine
        % Vertical CVaR line plot.
        CVaRLine
        % Legend.
        Legend
    end % properties (Access = private)
    
    % Private, internal data properties.
    properties (Access = private)
        % Chart data, typically a return series.
        Data_ = 0;
        % Value-at-risk level.
        VaRLevel_ = 0.95;
    end % properties (Access = private)
    
    methods
        
        function obj = ValueAtRisk( varargin )
            
            % Create a temporary figure to act as the chart axes' Parent.
            f = figure( 'Visible', 'off' );
            oc = onCleanup( @() delete( f ) );
            
            % Parent the chart's axes.
            obj.Parent = f;
            
            % Create the chart graphics.
            % First, draw the histogram with total area 1.
            obj.Histogram = histogram( obj.Axes, obj.Data_, ...
                'Normalization', 'pdf' );
            % Restore the axes' DeleteFcn.
            obj.Axes.DeleteFcn = @obj.onAxesDeleted;
            
            % Create the distribution fit.
            obj.DistributionFit = fitdist( obj.Data_, 'kernel' );
            % Evaluate it on the sample range.
            d = linspace( min( obj.Data_ ), max( obj.Data_ ), 1000 );
            y = pdf( obj.DistributionFit, d );
            % Overlay the density on the histogram.
            c = obj.Axes.ColorOrder;
            obj.Density = line( 'Parent', obj.Axes, ...
                                'XData', d, ...
                                'YData', y, ...
                                'LineWidth', 1.5, ...
                                'Color', c(2, :) );
            % Overlay the VaR lines.
            VaR = quantile( obj.Data_, 1 - obj.VaRLevel );
            CVaR = mean( obj.Data_(obj.Data_ < VaR) );
            y = obj.Axes.YLim;
            obj.VaRLine = line( 'Parent', obj.Axes, ...
                'XData', [VaR, VaR], ...
                'YData', y, ...
                'LineWidth', 2, ...
                'Color', 'm' );
            obj.CVaRLine = line( 'Parent', obj.Axes, ...
                'XData', [CVaR, CVaR], ...
                'YData', y, ...
                'LineWidth', 2, ...
                'Color', 'r' );
            % Create the legend.
            vl = num2str( 100 * obj.VaRLevel );
            legText = {'Data', 'Kernel density fit', ...
                ['VaR (', vl, ') = ', num2str( VaR )], ...
                ['CVaR (', vl, ') = ', num2str( CVaR )]};
            obj.Legend = legend( obj.Axes, legText, ...
                'Location', 'northeast' );
            
            % Remove the chart axes' temporary Parent.
            obj.Parent = [];            
            
            % Set the chart properties.
            if ~isempty( varargin )
                set( obj, varargin{:} );
            end % if
            
        end % ValueAtRisk constructor
        
        % Get/set methods for the public chart interface.
        
        function d = get.Data( obj )
            d = obj.Data_;
        end % get.Data
        
        function set.Data( obj, proposedData )
            % Validate and assign the new value.
            validateattributes( proposedData, {'double'}, ...
                {'real', 'column', 'nonempty'}, ...
                'ValueAtRisk/set.Data', 'the chart data' )
            if all( ~isfinite( proposedData ) )
                error( 'ValueAtRisk:AllMissing', 'Chart data cannot all be missing.' )
            end % if
            obj.Data_ = proposedData;
            % Update the chart.
            update( obj );
        end % set.Data
        
        function VaRLevel = get.VaRLevel( obj )
            VaRLevel = obj.VaRLevel_;
        end % get.VaRLevel
        
        function set.VaRLevel( obj, proposedLevel )
            validateattributes( proposedLevel, {'double'}, ...
                {'real', 'scalar', '>', 0, '<', 1}, ...
                'ValueAtRisk/set.VaRLevel', 'the value at risk level' )
            obj.VaRLevel_ = proposedLevel;
            % Update the VaR lines.
            updateVaRLines( obj );
        end % set.VaRLevel
        
        function xl = get.XLabel( obj )
            xl = obj.Axes.XLabel;
        end % get.XLabel
        
        function set.XLabel( obj, proposedXLabel )
            obj.Axes.XLabel = proposedXLabel;
        end % set.XLabel
        
        function yl = get.YLabel( obj )
            yl = obj.Axes.YLabel;
        end % get.YLabel
        
        function set.YLabel( obj, proposedYLabel )
            obj.Axes.YLabel = proposedYLabel;
        end % set.YLabel
        
        function t = get.Title( obj )
            t = obj.Axes.Title;
        end % get.Title
        
        function set.Title( obj, proposedTitle )
            obj.Axes.Title = proposedTitle;
        end % set.Title
        
        function legText = get.LegendText( obj )
            legText = obj.Legend.String;
        end % get.LegendText
        
        function set.LegendText( obj, proposedLegendText )
            assert( iscellstr( proposedLegendText ) && ...
                isvector( proposedLegendText ) && ...
                numel( proposedLegendText ) == 4, ...
                'ValueAtRisk:InvalidLegendText', ...
                'The legend text must be a cell array (of length 4) of character vectors.' )
            obj.Legend.String = proposedLegendText;
        end % set.LegendText
        
        function legFontSize = get.LegendFontSize( obj )
            legFontSize = obj.Legend.FontSize;
        end % get.LegendFontSize
        
        function set.LegendFontSize( obj, proposedLegendFontSize )
            obj.Legend.FontSize = proposedLegendFontSize;
        end % set.LegendFontSize
        
        function legLoc = get.LegendLocation( obj )
            legLoc = obj.Legend.Location;
        end % get.LegendLocation
        
        function set.LegendLocation( obj, proposedLegendLocation )
            obj.Legend.Location = proposedLegendLocation;
        end % set.LegendLocation
        
        function gridStatus = get.Grid( obj )
            gridStatus = obj.Axes.XGrid;
        end % get.Grid
        
        function set.Grid( obj, proposedGridStatus )
            set( obj.Axes, 'XGrid', proposedGridStatus, ...
                'YGrid', proposedGridStatus );
        end % set.Grid
        
        function s = get.DensityStyle( obj )
            s = obj.Density.LineStyle;
        end % get.DensityStyle
        
        function set.DensityStyle( obj, proposedLineStyle )
            obj.Density.LineStyle = proposedLineStyle;
        end % set.LineStyle
        
        function w = get.DensityWidth( obj )
            w = obj.Density.LineWidth;
        end % get.DensityWidth
        
        function set.DensityWidth( obj, proposedLineWidth )
            obj.Density.LineWidth = proposedLineWidth;
        end % set.DensityWidth
        
        function c = get.DensityColor( obj )
            c = obj.Density.Color;
        end % get.DensityColor
        
        function set.DensityColor( obj, proposedColor )
            obj.Density.Color = proposedColor;
        end % set.DensityColor
        
        function fa = get.FaceAlpha( obj )
            fa = obj.Histogram.FaceAlpha;
        end % get.FaceAlpha
        
        function set.FaceAlpha( obj, proposedFaceAlpha )
            obj.Histogram.FaceAlpha = proposedFaceAlpha;
        end % set.FaceAlpha
        
        function fc = get.FaceColor( obj )
            fc = obj.Histogram.FaceColor;
        end % get.FaceColor
        
        function set.FaceColor( obj, proposedFaceColor )
            obj.Histogram.FaceColor = proposedFaceColor;
        end % set.FaceColor        
        
    end % methods
    
    methods ( Access = private )
        
        function update( obj )
            % Redraw the chart graphics in response to data changes or on
            % construction.
            
            % Update the histogram. Note that the binning is not
            % automatically updated when the histogram data is changed.
            obj.Histogram.Data = obj.Data_;
            obj.Histogram.BinMethod = 'auto';
            % Evaluate the new y-limits for the chart axes.
            f = figure( 'Visible', 'off' );
            oc = onCleanup( @() delete( f ) );
            ax = axes( 'Parent', f );
            histogram( ax, obj.Data_, 'Normalization', 'pdf' );            
            % Update the current axes y-limits.
            obj.Axes.YLim = ax.YLim;            
            % Update the non-parametric distribution.
            obj.DistributionFit = fitdist( obj.Data_, 'kernel' );
            % Evaluate it on the sample range.
            d = linspace( min( obj.Data_ ), max( obj.Data_ ), 1000 );
            y = pdf( obj.DistributionFit, d );
            % Update the density plot.
            set( obj.Density, 'XData', d, 'YData', y )
            % Update the VaR lines.
            updateVaRLines( obj );
            
        end % update
        
        function updateVaRLines( obj )
            % Update the VaR lines if the VaR level has been changed.
            VaR = quantile( obj.Data_, 1 - obj.VaRLevel );
            CVaR = mean( obj.Data_(obj.Data_ < VaR) );
            % Current y-limits.
            y = obj.Axes.YLim;
            % Update the line data.
            set( obj.VaRLine, 'XData', [VaR, VaR], 'YData', y );
            set( obj.CVaRLine, 'XData', [CVaR, CVaR], 'YData', y );
            % Update the legend.
            vl = num2str( 100 * obj.VaRLevel );
            obj.Legend.String(3:4) = ...
                {['VaR (', vl, ') = ', num2str( VaR )], ...
                ['CVaR (', vl, ') = ', num2str( CVaR )]};
        end % updateVaRLines
        
    end % methods (Access = private)
    
end % class definition