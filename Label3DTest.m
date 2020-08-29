%% Test Class Definition
classdef Label3DTest < matlab.unittest.TestCase
    
    properties
        TestLabelGui
        camParams
        videos
        skeleton
    end
    
    methods (TestClassSetup)
        function addLabel3DClassToPath(testCase)
            p = path;
            testCase.addTeardown(@path,p);
            addpath(fullfile(pwd, 'test'));
            addpath(fullfile(pwd, 'skeletons'));
            addpath(genpath(fullfile(pwd, 'deps')));
            
            setup = load('test/test.mat');
            testCase.camParams = setup.camParams;
            testCase.videos = setup.videos;
            testCase.skeleton = load('rat16.mat');
        end
    end
    
    methods (TestMethodSetup)
        function createLabel3D(testCase)
            testCase.TestLabelGui = Label3D('test/test.mat');
        end
    end
    
    
    methods (TestMethodTeardown)
        function closeLabel3D(testCase)
            close(testCase.TestLabelGui.statusAnimator.Parent)
            close(testCase.TestLabelGui.jointsPanel.Parent)
            close(testCase.TestLabelGui.Parent)
        end
    end

    %% Test Method Block
    methods (Test)
        
        function testLabel3DConstructionFromScratch(testCase)
            testCase.closeLabel3D()
            testCase.TestLabelGui = Label3D(testCase.camParams, testCase.videos, testCase.skeleton);
            testCase.verifyClass(testCase.TestLabelGui, "Label3D");
        end
        
        function testLabel3DConstructionFromState(testCase)
            testCase.closeLabel3D()
            testCase.TestLabelGui = Label3D('test/labels1.mat', testCase.videos);
            testCase.verifyClass(testCase.TestLabelGui, "Label3D");
        end
          
        function testLabel3DConstructionFromFile(testCase)
            testCase.closeLabel3D()
            testCase.TestLabelGui = Label3D('test/test.mat');
            testCase.verifyClass(testCase.TestLabelGui, "Label3D");
        end
        
        function testLabel3DConstructionMerge(testCase)
            testCase.closeLabel3D()
            testCase.TestLabelGui = Label3D({'test/test.mat', 'test/test.mat'});
            testCase.verifyClass(testCase.TestLabelGui, "Label3D");
        end
        
        function testLabel3DExportDannceFailsIfNoFrameNumbersProvided(testCase)
            testCase.TestLabelGui.framesToLabel=[];
            test = @() testCase.TestLabelGui.exportDannce('saveFolder','test');
            testCase.verifyError(test, 'exportDannce:FrameNumbersMustBeProvided')
        end
        
        function testLabel3DExportDannce(testCase)
            testCase.TestLabelGui.exportDannce('saveFolder','test','framesToLabel', 1:3)
            file = sprintf('test/%s_dannce.mat', testCase.TestLabelGui.savePath);
            dannce = load(file);
            testCase.verifyEqual(size(dannce.labelData{1}.data_3d), [1 48])
            testCase.verifyEqual(dannce.labelData{1}.data_frame, 0)
            testCase.verifyEqual(dannce.labelData{1}.data_sampleID, 1)
            delete(sprintf('test/%s_dannce.mat', testCase.TestLabelGui.savePath))
            delete([testCase.TestLabelGui.savePath '.mat'])
        end
        
        function testLabel3DTriangulate(testCase)
            eventdata.Key = 't';
            testCase.TestLabelGui.keyPressCallback([], eventdata)
            delete([testCase.TestLabelGui.savePath '.mat'])
        end
        
        function testLabel3DTab(testCase)
            previousNode = testCase.TestLabelGui.selectedNode;
            eventdata.Key = 'tab';
            testCase.TestLabelGui.keyPressCallback([], eventdata)
            testCase.verifyEqual(testCase.TestLabelGui.selectedNode, previousNode+1);
        end  
        
        function testLabel3DResetFrame(testCase)
            eventdata.Key = 'u';
            testCase.TestLabelGui.keyPressCallback([], eventdata)
            testCase.verifyTrue(sum(testCase.TestLabelGui.status(:)) == 0);
        end
        
        function testLabel3DResetAspectRatio(testCase)
            eventdata.Key = 'a';
            testCase.TestLabelGui.keyPressCallback([], eventdata)
            % Write a check for the correct behavior
        end
        
        function testLabel3DSetFrame(testCase)
            testCase.TestLabelGui.setFrame(3)
            testCase.verifyEqual(testCase.TestLabelGui.frame, 3);
        end
        
        function testLabel3DSetLabeled(testCase)
            eventdata.Key = 'l';
            testCase.TestLabelGui.keyPressCallback([], eventdata)
            testCase.verifyEqual(sum(testCase.TestLabelGui.status(:)), 72);
            delete([testCase.TestLabelGui.savePath '.mat'])
        end
        
        function testLabel3DSaveAll(testCase)
            testCase.TestLabelGui.saveAll
            savePath = [testCase.TestLabelGui.savePath '_videos.mat'];
            saved = load(savePath);
            reference = load('test/test.mat');
            reference.savePath = saved.savePath;
            testCase.verifyEqual(saved, reference)
            delete(savePath)
        end
        
    end
end
