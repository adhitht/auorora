import grpc
from concurrent import futures
import time

from app import relighting_pb2_grpc
from app import pose_pb2_grpc
from app.service import RelightingService, PoseChangingService

def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    relighting_pb2_grpc.add_RelightingServiceServicer_to_server(RelightingService(), server)
    pose_pb2_grpc.add_PoseChangingServiceServicer_to_server(PoseChangingService(), server)
    server.add_insecure_port('[::]:50051')
    print("Server started on port 50051")
    server.start()
    try:
        while True:
            time.sleep(86400)
    except KeyboardInterrupt:
        server.stop(0)

if __name__ == '__main__':
    serve()