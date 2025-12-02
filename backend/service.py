import grpc
import io
import json
import numpy as np
from PIL import Image

from . import relighting_pb2
from . import relighting_pb2_grpc
from . import pose_pb2
from . import pose_pb2_grpc

from .ml_models import RelightingModel, PoseCorrectionPipeline
from .model.lights_model import LightsRequest

relight_pipeline = RelightingModel()
pose_pipeline = PoseCorrectionPipeline()

class RelightingService(relighting_pb2_grpc.RelightingServiceServicer):
    def Relight(self, request, context):
        try:
            image_data = request.image_data
            image = Image.open(io.BytesIO(image_data))
            
            lightmap = None
            if request.json_data:
                try:
                    lights_request = LightsRequest.model_validate_json(request.json_data)
                    lightmap = lights_request.lights
                except Exception as e:
                    print(f"Error parsing json_data: {e}")
            
            if request.mask_data:
                mask = Image.open(io.BytesIO(request.mask_data))
            else:
                mask = None

            processed_image = relight_pipeline.predict(image, mask, lights_config=lightmap)
            
            output_buffer = io.BytesIO()
            processed_image[0].save(output_buffer, format='PNG')
            # processed_image.save(output_buffer, format=save_format)
            processed_image_data = output_buffer.getvalue()
            
            return relighting_pb2.RelightResponse(processed_image_data=processed_image_data)
        except Exception as e:
            print(f"Error processing request: {e}")
            context.set_details(str(e))
            context.set_code(grpc.StatusCode.INTERNAL)
            return relighting_pb2.RelightResponse()

class PoseChangingService(pose_pb2_grpc.PoseChangingServiceServicer):
    def ChangePose(self, request, context):
        try:
            image_data = request.image_data
            image = Image.open(io.BytesIO(image_data))
            
            offset_config = []
            if request.new_skeleton_data:
                try:
                    json_str = request.new_skeleton_data.decode('utf-8')
                    offset_config = json.loads(json_str)
                    print(f"Received offset config: {offset_config}")
                except Exception as e:
                    print(f"Error parsing new_skeleton_data: {e}")
                    raise ValueError("Invalid skeleton data format")

            if not offset_config:
                 # If no config, return original image
                 print("No offset config provided, returning original image")
                 processed_image = image
            else:
                processed_image = pose_pipeline.process_request(image_data, offset_config)
            
            output_buffer = io.BytesIO()
            processed_image.save(output_buffer, format='PNG')
            processed_image_data = output_buffer.getvalue()
            
            return pose_pb2.PoseResponse(processed_image_data=processed_image_data)
        except Exception as e:
            print(f"Error processing pose request: {e}")
            context.set_details(str(e))
            context.set_code(grpc.StatusCode.INTERNAL)
            return pose_pb2.PoseResponse()