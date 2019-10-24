# Label3D

Label3D is a GUI for manual labeling of 3D keypoints in multiple cameras.

## Features
1. Simultaneous viewing of any number of camera views.
2. Multiview triangulation of 3D keypoints.
3. Point-and-click and draggable gestures to label keypoints.
4. Zooming, panning, and other default Matlab gestures
5. Integration with `Animator` classes.

## Instructions
*right*: move forward one frameRate
*left*: move backward one frameRate
*up*: increase the frameRate
*down*: decrease the frameRate
*t*: triangulate points in current frame that have been labeled in at least two images and reproject into each image
*r*: reset gui to the first frame and remove `Animator` restrictions
*u*: reset the current frame to the initial marker positions
*z*: zoom all images out to full size
*tab*: shift the selected node by 1
*ctrl+tab* or backspace: shift the selected node by -1
*shift+s*: save data to a `.mat` file
*h*: print help messages for all `Animators`

Written by Diego Aldarondo (2019)
Some code adapted from https://github.com/talmo/leap
