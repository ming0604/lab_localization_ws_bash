#!/bin/bash
source ~/anaconda3/bin/activate evo_tool 

# set white background and gray grid for evoplots
evo_config set plot_seaborn_style whitegrid

# Check if the correct number of arguments are provided (11 arguments)
if [ "$#" -ne 11 ]; then
  echo "Usage: $0 <bag1> <bag2> <bag3> <alg1_name> <alg2_name> <alg3_name> <output_folder_name> <yaml1> <yaml2> <yaml3> <ground_truth_topic>"
  echo "Example: $0 run1.bag run2.bag run3.bag \"AMCL + Gmapping map\" \"AMCL + PLICP + Gmapping map\" \"AMCL + PLICP + Vive mapping map\" compare_res bag1_map.yaml bag2_map.yaml bag3_map.yaml /base_gt_odom"
  exit 1
fi

bag1=$1
bag2=$2
bag3=$3
alg1=$4
alg2=$5
alg3=$6
output_folder_name=$7
yaml1=$8
yaml2=$9
yaml3=${10}
ground_truth_topic=${11}

cd ~/lab_localization/bag

for bag_file in "$bag1" "$bag2" "$bag3"; do
  if [ ! -f "${bag_file}" ]; then
    echo "Can't find bag file: $bag_file"
    exit 1
  fi
done

for yaml_file in "$yaml1" "$yaml2" "$yaml3"; do
  if [ ! -f "${yaml_file}" ]; then
    echo "Can't find yaml file: $yaml_file"
    exit 1
  fi
done

# output dir
parent_output_folder="/home/mingzhun/lab_localization/evo_result"
output_folder="$parent_output_folder/$output_folder_name"

# Check if the output folder already exists, prompt for overwrite if it does
if [ -d "$output_folder" ]; then
    read -p "The folder already exists. Do you want to overwrite it? (y/n): " choice
    if [ "$choice" == "y" ]; then
        echo "Overwriting folder: $output_folder"
        rm -rf "$output_folder"
    else
        echo "Using existing folder: ${output_folder}"
    fi
fi

# Create the output folder and subfolders
mkdir -p "$output_folder/tum" "$output_folder/plot" "$output_folder/trans_result" "$output_folder/rot_result"

# Remove leading '/' and replace remaining '/' with '_' to match evo --save_as_tum default filenames
clean_gt=$(echo "$ground_truth_topic" | sed 's/^\///; s/\//_/g')
clean_pose="freq_pose"

# Step 1: Export trajectories to .tum files so legend names match algorithm names and "ground truth"
cd "$output_folder/tum"

evo_traj bag ~/lab_localization/bag/"$bag1" "$ground_truth_topic" /freq_pose --save_as_tum
mv "${clean_gt}.tum" "ground truth.tum"
mv "${clean_pose}.tum" "${alg1}.tum"

evo_traj bag ~/lab_localization/bag/"$bag2" /freq_pose --save_as_tum
mv "${clean_pose}.tum" "${alg2}.tum"

evo_traj bag ~/lab_localization/bag/"$bag3" /freq_pose --save_as_tum
mv "${clean_pose}.tum" "${alg3}.tum"

cd ~/lab_localization/bag

# Step 2: Run the evo_traj command for all 3 algorithms and save the combined plot
evo_traj tum "$output_folder/tum/${alg1}.tum" "$output_folder/tum/${alg2}.tum" "$output_folder/tum/${alg3}.tum" --ref "$output_folder/tum/ground truth.tum" -v -p --plot_mode xy --save_plot "$output_folder/plot/combined_traj"
echo "evo_traj command executed successfully. Results saved in: $output_folder"

# Step 3: Run the evo_ape command for translation and rotation APE
# Save without extension temporarily so evo_res --use_filenames displays exact algorithm names

# Algorithm 1
evo_ape bag "$bag1" "$ground_truth_topic" /freq_pose -v -p --plot_mode xy --save_plot "$output_folder/plot/${alg1}_trans" --ros_map_yaml "$yaml1" --save_result "$output_folder/trans_result/${alg1}"
evo_ape bag "$bag1" "$ground_truth_topic" /freq_pose -v -p --plot_mode xy --save_plot "$output_folder/plot/${alg1}_rot" --ros_map_yaml "$yaml1" --save_result "$output_folder/rot_result/${alg1}" -r angle_deg

# Algorithm 2
evo_ape bag "$bag2" "$ground_truth_topic" /freq_pose -v -p --plot_mode xy --save_plot "$output_folder/plot/${alg2}_trans" --ros_map_yaml "$yaml2" --save_result "$output_folder/trans_result/${alg2}"
evo_ape bag "$bag2" "$ground_truth_topic" /freq_pose -v -p --plot_mode xy --save_plot "$output_folder/plot/${alg2}_rot" --ros_map_yaml "$yaml2" --save_result "$output_folder/rot_result/${alg2}" -r angle_deg

# Algorithm 3
evo_ape bag "$bag3" "$ground_truth_topic" /freq_pose -v -p --plot_mode xy --save_plot "$output_folder/plot/${alg3}_trans" --ros_map_yaml "$yaml3" --save_result "$output_folder/trans_result/${alg3}"
evo_ape bag "$bag3" "$ground_truth_topic" /freq_pose -v -p --plot_mode xy --save_plot "$output_folder/plot/${alg3}_rot" --ros_map_yaml "$yaml3" --save_result "$output_folder/rot_result/${alg3}" -r angle_deg

# Step 4: Run evo_res with --use_filenames, then rename results to *_trans.zip and *_rot.zip
cd "$output_folder/trans_result"
evo_res "${alg1}" "${alg2}" "${alg3}" --use_filenames -v -p --save_plot "$output_folder/plot/compare_trans" --save_table "$output_folder/trans_result/trans_table.csv"
mv "${alg1}" "${alg1}_trans.zip"
mv "${alg2}" "${alg2}_trans.zip"
mv "${alg3}" "${alg3}_trans.zip"

cd "$output_folder/rot_result"
evo_res "${alg1}" "${alg2}" "${alg3}" --use_filenames -v -p --save_plot "$output_folder/plot/compare_rot" --save_table "$output_folder/rot_result/rot_table.csv"
mv "${alg1}" "${alg1}_rot.zip"
mv "${alg2}" "${alg2}_rot.zip"
mv "${alg3}" "${alg3}_rot.zip"