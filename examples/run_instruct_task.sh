#!/bin/bash

TASK_ID="203018b2-96f6-4263-a86e-0cc510266b9b"
MODEL="princeton-nlp/Sheared-LLaMA-1.3B"
DATASET="https://gradients.s3.eu-north-1.amazonaws.com/4e92191dccb1ecaa_train_data.json?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAVVZOOA7SA4UOFLPI%2F20250902%2Feu-north-1%2Fs3%2Faws4_request&X-Amz-Date=20250902T100815Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=6cab4ec0898631f380ccd5a575e589876888fe4766097ae8feaa06b8033421c1"
DATASET_TYPE='{
  "field_instruction":"instruct",
  "field_input": "input",
  "field_output":"output"
}'
FILE_FORMAT="s3"
HOURS_TO_COMPLETE=2


# For uploading the outputs
HUGGINGFACE_TOKEN=""
WANDB_TOKEN=""
HUGGINGFACE_USERNAME="haihp02"
EXPECTED_REPO_NAME="instructtest"
LOCAL_FOLDER="/home/user/sn56_tournament/$TASK_ID/$EXPECTED_REPO_NAME"


CHECKPOINTS_DIR="/home/user/sn56_tournament/secure_checkpoints"
OUTPUTS_DIR="/home/user/sn56_tournament/outputs"
mkdir -p "$CHECKPOINTS_DIR"
chmod 777 "$CHECKPOINTS_DIR"
mkdir -p "$OUTPUTS_DIR"
chmod 777 "$OUTPUTS_DIR"

# Build the downloader image
docker build -t trainer-downloader -f dockerfiles/trainer-downloader.dockerfile .

# Build the trainer image
docker build -t standalone-text-trainer -f dockerfiles/standalone-text-trainer.dockerfile .

# Build the hf uploader image
docker build -t hf-uploader -f dockerfiles/hf-uploader.dockerfile .

# Download model and dataset
# echo "Downloading model and dataset..."
# docker run --rm \
#   --volume "$CHECKPOINTS_DIR:/cache:rw" \
#   --name downloader-image \
#   trainer-downloader \
#   --task-id "$TASK_ID" \
#   --model "$MODEL" \
#   --dataset "$DATASET" \
#   --file-format "$FILE_FORMAT" \
#   --task-type "InstructTextTask"


docker run --rm --gpus all \
  --security-opt=no-new-privileges \
  --cap-drop=ALL \
  --memory=64g \
  --cpus=8 \
  --network none \
  --volume "$CHECKPOINTS_DIR:/cache:rw" \
  --volume "$OUTPUTS_DIR:/app/checkpoints/:rw" \
  --name instruct-text-trainer-example \
  standalone-text-trainer \
  --task-id "$TASK_ID" \
  --model "$MODEL" \
  --dataset "$DATASET" \
  --dataset-type "$DATASET_TYPE" \
  --task-type "InstructTextTask" \
  --file-format "$FILE_FORMAT" \
  --hours-to-complete "$HOURS_TO_COMPLETE" \
  --expected-repo-name "$EXPECTED_REPO_NAME" \


  # Upload the trained model to HuggingFace
echo "Uploading model to HuggingFace..."
docker run --rm --gpus all \
  --volume "$OUTPUTS_DIR:/app/checkpoints/:rw" \
  --env HUGGINGFACE_TOKEN="$HUGGINGFACE_TOKEN" \
  --env HUGGINGFACE_USERNAME="$HUGGINGFACE_USERNAME" \
  --env WANDB_TOKEN="$WANDB_TOKEN" \
  --env TASK_ID="$TASK_ID" \
  --env EXPECTED_REPO_NAME="$EXPECTED_REPO_NAME" \
  --env LOCAL_FOLDER="$LOCAL_FOLDER" \
  --name hf-uploader \
  hf-uploader

