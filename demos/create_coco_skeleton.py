import numpy as np
from scipy.io import savemat
import os

# --- Configuration ---
OUTPUT_FILENAME = "coco17_skeleton.mat"
OUTPUT_DIR = "skeletons" # Relative path for the output directory (consistent with Label3D structure)

# --- Skeleton Definition (COCO 17 Keypoints) ---

# 1. Joint Names (1x17 cell array)
joint_names = [
    'nose', 'left_eye', 'right_eye', 'left_ear', 'right_ear', 
    'left_shoulder', 'right_shoulder', 'left_elbow', 'right_elbow', 
    'left_wrist', 'right_wrist', 'left_hip', 'right_hip', 
    'left_knee', 'right_knee', 'left_ankle', 'right_ankle'
]
# Ensure it's a 1xN structure for MATLAB cell compatibility
joint_names_np = np.array(joint_names, dtype=object).reshape(1, -1)

# 2. Joint Connections (Nx2 matrix of 1-based indices)
# Pairs define the connections: [joint_start_index, joint_end_index]
# Indices are 1-based corresponding to the joint_names list
joints_idx = np.array([
    # Head group
    [1, 2],  # nose -> left_eye
    [2, 4],  # left_eye -> left_ear
    [1, 3],  # nose -> right_eye
    [3, 5],  # right_eye -> right_ear
    [4, 6],  # left_ear -> left_shoulder
    [5, 7],  # right_ear -> right_shoulder
    # Body group
    [6, 7],  # left_shoulder -> right_shoulder
    [12, 13], # left_hip -> right_hip
    [6, 12], # left_shoulder -> left_hip
    [7, 13], # right_shoulder -> right_hip
    # Left arm group
    [6, 8],  # left_shoulder -> left_elbow
    [8, 10], # left_elbow -> left_wrist
    # Right arm group
    [7, 9],  # right_shoulder -> right_elbow
    [9, 11], # right_elbow -> right_wrist
    # Left leg group
    [12, 14], # left_hip -> left_knee
    [14, 16], # left_knee -> left_ankle
    # Right leg group
    [13, 15], # right_hip -> right_knee
    [15, 17]  # right_knee -> right_ankle
], dtype=np.uint8) # Use uint8 for indices, sufficient for 17 points

# 3. Connection Colors (Nx3 matrix of RGB values 0-1)
# Colors correspond row-wise to joints_idx
# Define some base colors
blue   = [0, 0, 1]
red    = [1, 0, 0]
green  = [0, 1, 0]
yellow = [1, 1, 0]
purple = [1, 0, 1]
cyan   = [0, 1, 1]
white  = [1, 1, 1]

# Assign colors logically
colors = np.array([
    # Head group (yellow)
    yellow, yellow, yellow, yellow, yellow, yellow,
    # Body group (white)
    white, white, white, white,
    # Left arm group (blue)
    blue, blue, 
    # Right arm group (red)
    red, red,
    # Left leg group (cyan)
    cyan, cyan,
    # Right leg group (purple)
    purple, purple
], dtype=np.float32)

# --- Validation ---
num_connections = joints_idx.shape[0]
num_colors = colors.shape[0]

if num_connections != num_colors:
    raise ValueError(f"Mismatch: Number of connections ({num_connections}) does not match number of colors ({num_colors}).")
if joints_idx.shape[1] != 2:
     raise ValueError(f"joints_idx should have 2 columns, but has {joints_idx.shape[1]}.")
if colors.shape[1] != 3:
     raise ValueError(f"colors should have 3 columns (RGB), but has {colors.shape[1]}.")
if np.max(joints_idx) > len(joint_names):
     raise ValueError("A joint index in joints_idx is larger than the number of joint names.")
if np.min(joints_idx) < 1:
     raise ValueError("Joint indices in joints_idx must be 1-based.")

# --- Create Data Dictionary for savemat ---
# Note: The structure created by savemat from this dict will be directly usable as the 'skeleton' struct in MATLAB
skeleton_data = {
    'joint_names': joint_names_np,
    'joints_idx': joints_idx,
    'color': colors
}

# --- Save .mat File ---
def main():
    # Create output directory if it doesn't exist
    if not os.path.exists(OUTPUT_DIR):
        print(f"Creating output directory: {OUTPUT_DIR}")
        os.makedirs(OUTPUT_DIR)
    else:
        print(f"Output directory already exists: {OUTPUT_DIR}")
        
    output_path = os.path.join(OUTPUT_DIR, OUTPUT_FILENAME)
    print(f"Saving COCO 17 skeleton data to: {output_path}")
    
    try:
        # Save the dictionary. `oned_as='row'` helps ensure joint_names becomes a 1xN cell
        savemat(output_path, skeleton_data, do_compression=True, oned_as='row')
        print("Successfully saved skeleton file.")
    except Exception as e:
        print(f"Error saving .mat file: {e}")

if __name__ == "__main__":
    main() 