# Curious_SS

Curious_SS is a curiosity experiment using arbitrary shapes presented in scenes to create associations within those scenes. The project is implemented in MATLAB and is organized for reproducibility and collaboration.

testing a change

## Project Overview

Participants are given a visual search task to search for a previously cued target shape. In this task a set of critical distractor objects appear in each scene with regularity (e.g., they appear either on the wall, counter, or floor 100% of trials). Then after participants have successfully found the cued target participants are given a free viewing period where they can search the scene how they wish. Then in the second half of the experiment we make it so that the critical distractors become the target set. We hypothesize that participants that do more visual exploration in the scene will have better guidance to the targets that were previously distractors.

## Project info

![MATLAB](https://img.shields.io/badge/MATLAB-R2023b-orange?logo=matlab&logoColor=white)
![License](https://img.shields.io/github/license/justin-frandsen/curious_ss)
![Last Commit](https://img.shields.io/github/last-commit/justin-frandsen/curious_ss)
![Issues](https://img.shields.io/github/issues/justin-frandsen/curious_ss)
![GitHub Repo Size](https://img.shields.io/github/repo-size/justin-frandsen/curious_ss)


## Folder Structure
```
├── .gitignore # Git ignore rules
├── LICENSE # License file
├── README.md # Project documentation
├── curious_ss.m # Main experiment script
│
├── /data/ # Experimental output data (gitignored)
│
├── /setup/ # Setup files and configuration scripts
│ ├── centralFixation.m
│ ├── experiment_setup.m
│ ├── image_stimuli_import.m
│ ├── instruct_curious_ss.m
│ ├── log_session_info.m
│ ├── pfp_ptb_cleanup.m
│ ├── pfp_ptb_init.m
│ ├── practice.m
│ ├── randomizor_curious.m
│ ├── screenshot.m
│ ├── setup_eyelink.m
│ ├── showInstructions.m
│ ├── shuffle_matrix.m
│ └── /location_scripts/ # Scripts for stimulus/shape positioning
│ ├── location_overlap_checker_css.m
│ ├── shape_position_checker_css.m
│ └── shape_position_finder_css.m
│
├── /Stimuli/ # Stimuli files (images, shapes, etc.)
│ ├── /scenes/
│ │ ├── /main/ # Main experiment scene stimuli
│ │ └── /practice/ # Practice scene stimuli
│ └── /shapes/ # Shape stimuli
│ └── ... # (subfolders for different shape types/purposes)
│
└── /trial_structure_files/ # Generated trial structure files
├── randomizor.mat
└── shape_positions.mat
```
## Getting Started

1. Clone the repository:
   ```sh
   git clone https://github.com/justin-frandsen/curious_ss
   ```
2. Navigate to the project directory:
   ```sh
   cd curious_ss
   ```
4. Run the main script in MATLAB to start the experiment:
   ```matlab
   curious_ss
   ```

## Usage

- Modify `setupfiles/fullRandomizor.m` to configure experiment parameters (e.g., number of trials, stimuli types).
- Add or replace stimuli in the `/stimuli/` folder.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Thank you to all the participants, Dr. Brian Anderson, and the Learning and Attention Lab who all made this project possible.

