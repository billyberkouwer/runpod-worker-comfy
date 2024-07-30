# Stage 1: Base image with common dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 as base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1 

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    wget

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Clone ComfyUI repository
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui

# Change working directory to ComfyUI
WORKDIR /comfyui

# Install ComfyUI dependencies
RUN pip3 install --upgrade --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 \
    && pip3 install --upgrade -r requirements.txt

# Install runpod
RUN pip3 install runpod requests

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Add the start and the handler
ADD src/start.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh

# Stage 2: Download models
FROM base as downloader

ARG HUGGINGFACE_ACCESS_TOKEN
ARG MODEL_TYPE

# Change working directory to ComfyUI
WORKDIR /comfyui

# Download checkpoints/vae/LoRA to include in image based on model type
RUN if [ "$MODEL_TYPE" = "sdxl" ]; then \
      wget -O models/checkpoints/sd_xl_base_1.0.safetensors https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors && \
      wget -O models/vae/sdxl_vae.safetensors https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors && \
      wget -O models/vae/sdxl-vae-fp16-fix.safetensors https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors; \
    elif [ "$MODEL_TYPE" = "sd3" ]; then \
      wget --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/checkpoints/sd3_medium_incl_clips_t5xxlfp8.safetensors https://huggingface.co/stabilityai/stable-diffusion-3-medium/resolve/main/sd3_medium_incl_clips_t5xxlfp8.safetensors; \
    fi

RUN wget -O models/checkpoints/sd_turbo.safetensors https://huggingface.co/stabilityai/sdturbo/resolve/main/sd_turbo.safetensors;
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git custom-nodes/ComfyUI-Manager;
RUN git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git custom-nodes/ComfyUI-Impact-Pack;
RUN git clone https://github.com/Derfuu/Derfuu_ComfyUI_ModdedNodes.git custom-nodes/Derfuu_ComfyUI_ModdedNodes;
RUN git clone https://github.com/WASasquatch/was-node-suite-comfyui.git custom-nodes/was-node-suite-comfyui;
RUN git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git custom-nodes/ComfyUI-Custom-Scripts;
RUN git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git custom-nodes/ComfyUI_Comfyroll_CustomNodes;
RUN git clone https://github.com/FizzleDorf/ComfyUI_FizzNodes.git custom-nodes/ComfyUI_FizzNodes;
RUN git clone https://github.com/jamesWalker55/comfyui-various.git custom-nodes/comfyui-various;
RUN git clone https://github.com/cubiq/ComfyUI_essentials.git custom-nodes/ComfyUI_essentials;
RUN git clone https://github.com/shadowcz007/comfyui-mixlab-nodes.git custom-nodes/comfyui-mixlab-nodes;
RUN git clone https://github.com/Amorano/Jovimetrix.git custom-nodes/Jovimetrix;
RUN git clone https://github.com/gokayfem/ComfyUI_VLM_nodes.git custom-nodes/ComfyUI_VLM_nodes;
RUN git clone https://github.com/kadirnar/ComfyUI-YOLO.git custom-nodes/ComfyUI-YOLO;
RUN git clone https://github.com/BadCafeCode/masquerade-nodes-comfyui.git custom-nodes/masquerade-nodes-comfyui;
RUN git clone https://github.com/sipherxyz/comfyui-art-venture.git custom-nodes/comfyui-art-venture;
RUN git clone https://github.com/twri/sdxl_prompt_styler.git custom-nodes/sdxl_prompt_styler;
RUN git clone https://github.com/hylarucoder/ComfyUI-Eagle-PNGInfo.git custom-nodes/ComfyUI-Eagle-PNGInfo;
RUN wget -O models/loras/mantra_alias.safetensors https://raw.githubusercontent.com/billyberkouwer/temp/main/mantra_alias.safetensors;
RUN wget -O models/vae_approx/taesd_decoder.pth https://raw.githubusercontent.com/billyberkouwer/temp/main/taesd_decoder.pth;
RUN wget -O models/vae_approx/taesd_encoder.pth https://raw.githubusercontent.com/billyberkouwer/temp/main/taesd_encoder.pth;
RUN wget -O models/vae/taesd_decoder.safetensors https://huggingface.co/madebyollin/taesdxl/resolve/main/taesdxl_decoder.safetensors?download=true;
RUN wget -O models/vae/taesd_encoder.safetensors https://huggingface.co/madebyollin/taesdxl/resolve/main/taesdxl_encoder.safetensors?download=true;

# Stage 3: Final image
FROM base as final

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models

# Start the container
CMD /start.sh
