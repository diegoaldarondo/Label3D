classdef Label3DCOMTest < Label3DTest
    methods (TestClassSetup)
        function addLabel3DClassToPath(testCase)
            addLabel3DClassToPath@Label3DTest(testCase)
            testCase.skeleton = load('com.mat');
        end
    end
    
    methods (TestMethodSetup)
        function createLabel3D(testCase)
            testCase.TestLabelGui = Label3D('labels2.mat', testCase.videos);
        end
    end
    
    methods (Test)
        function testLabel3DSetLabeled(testCase)
            eventdata.Key = 'l';
            testCase.TestLabelGui.keyPressCallback([], eventdata)
            testCase.verifyEqual(sum(testCase.TestLabelGui.status(:)), 12);
        end
        
        function testLabel3DSaveAll(testCase)
            testCase.TestLabelGui.saveAll
            savePath = [testCase.TestLabelGui.savePath '_videos.mat'];
            saved = load(savePath);
            reference = load('labels2.mat');
            reference.savePath = saved.savePath;
            testCase.verifyEqual(saved.data_3D, reference.data_3D)
            testCase.verifyEqual(saved.camParams, reference.camParams)
            testCase.verifyEqual(saved.sync, reference.sync)
            testCase.verifyEqual(saved.skeleton, reference.skeleton)
            videoReference = load('test.mat');
            testCase.verifyEqual(saved.videos, videoReference.videos)
        end
        
        function testLabel3DTab(testCase)
            eventdata.Key = 'tab';
            testCase.TestLabelGui.keyPressCallback([], eventdata)
            testCase.verifyEqual(testCase.TestLabelGui.selectedNode, 1);
        end
    end
end