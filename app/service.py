import grpc
import io
import numpy as np
from PIL import Image

from app import relighting_pb2
from app import relighting_pb2_grpc
from app.model import RelightingModel

model_instance = RelightingModel()

class RelightingService(relighting_pb2_grpc.RelightingServiceServicer):
    def Relight(self, request, context):
        try:
            image_data = request.image_data
            image = Image.open(io.BytesIO(image_data))
            
            lightmap = None
            if request.lightmap_data:
                lightmap = Image.open(io.BytesIO(request.lightmap_data))

            processed_image = model_instance.predict(image, lightmap)
            
            output_buffer = io.BytesIO()
            processed_image.save(output_buffer, format='PNG')
            # save_format = image.format if image.format else 'PNG'
            # processed_image.save(output_buffer, format=save_format)
            processed_image_data = output_buffer.getvalue()
            
            return relighting_pb2.RelightResponse(processed_image_data=processed_image_data)
        except Exception as e:
            print(f"Error processing request: {e}")
            context.set_details(str(e))
            context.set_code(grpc.StatusCode.INTERNAL)
            return relighting_pb2.RelightResponse()