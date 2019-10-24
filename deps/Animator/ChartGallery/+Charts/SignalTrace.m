classdef SignalTrace < Chart
    %SIGNALTRACE Chart for managing a collection of non-overlapping signal
    %traces plotted against a numeric time vector.
    %
    % Copyright 2018 The MathWorks, Inc.
    
    properties ( Hidden, Constant )
        % Product dependencies.
        Dependencies = {'MATLAB'};
    end % properties ( Hidden, Constant )
    
    % Public interface properties.
    properties ( Dependent )
        % Chart time data.
        Time
        % Chart signal data.
        SignalData
        % Axes x-label.
        XLabel
        % Axes y-label.
        YLabel
        % Axes title.
        Title
        % Axes x-axis.
        XAxis
        % Width of the signal traces.
        SignalLineWidth
    end % properties ( Dependent )
    
    properties ( Access = private )
        % Backing property for the time data.
        Time_ = double.empty( 0, 1 );
        % Backing property for the signal data.
        SignalData_ = double.empty( 0, 1 );
        % Signal trace line objects.
        SignalLines
    end % properties ( Access = private )
    
    properties ( Dependent, Access = private )
        % Translated signal data, adapted for display on the chart.
        OffsetSignalData
    end % properties ( Dependent, Access = private )
    
    methods
        
        function obj = SignalTrace( varargin )
            
            % Create the chart graphics.
            nSignals = size( obj.SignalData_, 2 );
            obj.SignalLines = gobjects( nSignals, 1 );
            for k = 1 : nSignals
                obj.SignalLines(k, 1) = line( 'Parent', obj.Axes, ...
                    'XData', [], ...
                    'YData', [], ...
                    'Color', 'y', ...
                    'LineWidth', 1.5 );
            end % for
            
            % Customize the axes appearance.
            obj.Axes.Color = [0.0, 0.5, 0.5];
            obj.Axes.XGrid = 'on';
            obj.Axes.YGrid = 'on';
            obj.Axes.YTickLabel = [];
            obj.Axes.GridColor = 'w';
            
            % Set the chart properties.
            if ~isempty( varargin )
                set( obj, varargin{:} );
            end % if
            
        end % constructor
        
        % Get/set methods.
        function t = get.Time( obj )
            t = obj.Time_;
        end % get.Time
        
        function set.Time( obj, proposedTime )
            
            % Validate the proposed time data.
            validateattributes( proposedTime, {'double'}, ...
                {'vector', 'real', 'finite', 'increasing'}, ...
                'SignalTrace/set.Time', 'the time data' )
            % Current data lengths.
            nT = numel( proposedTime );
            nS = size( obj.SignalData_, 1 );
            % Decide how to proceed based on the data lengths.
            if nT > nS
                % Pad the existing signal data.
                obj.SignalData_(end+1:nT, :) = NaN;
            else
                % Truncate the existing signal data.
                obj.SignalData_ = obj.SignalData_(1:nT, :);
            end % if
            
            % Set the internal time.
            obj.Time_ = proposedTime(:);
            
            % Update the chart.
            update( obj );
            
        end % set.Time
        
        function s = get.SignalData( obj )
            s = obj.SignalData_;
        end % get.SignalData
        
        function set.SignalData( obj, proposedSignalData )
            
            % Validate the new signal data.
            validateattributes( proposedSignalData, {'double'}, ...
                {'2d', 'nonempty', 'real', 'finite'}, ...
                'SignalTrace/set.SignalData', 'the signal data' )
            
            % Current data lengths.
            nT = numel( obj.Time_ );
            nS = size( proposedSignalData, 1 );
            % Decide how to proceed based on the data lengths.
            if nS > nT
                % Pad the existing time data.
                obj.Time_(end+1:nS, :) = NaN;
            else
                % Truncate the existing time data.
                obj.Time_ = obj.Time_(1:nS, :);
            end % if
            
            % Set the internal signal data.
            obj.SignalData_ = proposedSignalData;
            
            % Update the chart graphics.
            update( obj );
            
        end % set.SignalData
        
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
        
        function xax = get.XAxis( obj )
            xax = obj.Axes.XAxis;
        end % get.XAxis
        
        function set.XAxis( obj, proposedXAxis )
            obj.Axes.XAxis = proposedXAxis;
        end % set.XAxis
        
        function slw = get.SignalLineWidth( obj )
            slw = obj.SignalLines(1).LineWidth;
        end % get.SignalLineWidth
        
        function set.SignalLineWidth( obj, proposedLineWidth )
            set( obj.SignalLines, 'LineWidth', proposedLineWidth );
        end % set.SignalLineWidth
        
        function osd = get.OffsetSignalData( obj )
            % Rescale the data, and then for each signal, offset it from
            % the previous one, leaving a small gap. Constant signals are
            % not rescaled.
            % Identify the constant signals.
            constSigIdx = all( diff( obj.SignalData_ ) == 0 )  | ...
                all( isnan( obj.SignalData_ ) );
            % Apply the z-score transformation to the non-constant signals.
            osd = obj.SignalData_;
            nonConstantSignals = obj.SignalData_(:, ~constSigIdx);
            osd(:, ~constSigIdx) = ...
                (nonConstantSignals - ...
                 mean( nonConstantSignals, 'omitnan' )) ./ ...
                 std( nonConstantSignals, 'omitnan' );
            % Cumulatively offset each signal from the previous one,
            % leaving a gap of size 0.5 between each pair of consecutive
            % signals.
            for k = 2 : size( osd, 2 )
                osd(:, k) = osd(:, k) + max( osd(:, k-1) ) + ...
                    abs( min( osd(:, k) ) ) + 0.5;
            end % for
            
        end % get.OffsetSignalData
        
    end % methods
    
    methods ( Access = private )
        
        function update( obj )
            
            % Update the signal trace lines with the new data.
            nTraces = size( obj.SignalData_, 2 );
            nLines = numel( obj.SignalLines );
            % If we have more traces, then we need to create new line
            % objects.
            if nTraces >= nLines
                nToAdd = nTraces - nLines;
                for k = 1 : nToAdd
                    obj.SignalLines(end+1, 1) = line( ...
                        'Parent', obj.Axes, ...
                        'XData', [], ...
                        'YData', [], ...
                        'Color', 'y', ...
                        'LineWidth', 1.5 );
                end % for
                % Otherwise, we need to delete the unneeded line objects and
                % remove their references from the chart object.
            else
                nToRemove = nLines - nTraces;
                delete( obj.SignalLines(end-nToRemove+1:end) );
                obj.SignalLines = obj.SignalLines(1:end-nToRemove);
            end % if
            
            % Refresh the line x and y data.
            for k = 1 : nTraces
                set( obj.SignalLines(k), 'XData', obj.Time_, ...
                    'YData', obj.OffsetSignalData(:, k) );
            end % for
            
            % Adjust the axes' y-limits.
            if ~all( isnan( obj.OffsetSignalData(:) ) )
                obj.Axes.YLim = [min( obj.OffsetSignalData(:) ) - 0.5, ...
                    max( obj.OffsetSignalData(:) ) + 0.5];
            end % if
            
            % Adjust the axes' x-limits.
            if ~all( isnan( obj.Time_ ) )
                obj.Axes.XLim = [min( obj.Time_ ), max( obj.Time_ )];
            end % if
            
        end % update
        
    end % methods ( Access = private )
    
end % class definition