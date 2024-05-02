import asyncio
import websockets
import json
import hashlib
import base64

'''
Run this command to get necessary library
pip install websockets
'''
async def toggle_recording():
    uri = "ws://localhost:4444"  # Adjust the port if different
    password = "your_password_here"  # Replace with your OBS WebSocket password

    async with websockets.connect(uri) as websocket:
        # Request authentication requirements
        auth_request = json.dumps({
            "request-type": "GetAuthRequired",
            "message-id": "1"
        })
        await websocket.send(auth_request)
        auth_response = json.loads(await websocket.recv())

        if auth_response['authRequired']:
            secret = base64.b64encode(hashlib.sha256((password + auth_response['salt']).encode('utf-8')).digest()).decode('utf-8')
            auth_response_hash = base64.b64encode(hashlib.sha256((secret + auth_response['challenge']).encode('utf-8')).digest()).decode('utf-8')
            auth_submit = json.dumps({
                "request-type": "Authenticate",
                "message-id": "2",
                "auth": auth_response_hash
            })
            await websocket.send(auth_submit)
            auth_submit_response = json.loads(await websocket.recv())
            if not auth_submit_response['status'] == 'ok':
                return  # Authentication failed

        # Check the current recording status
        recording_status_request = json.dumps({
            "request-type": "GetRecordingStatus",
            "message-id": "3"
        })
        await websocket.send(recording_status_request)
        recording_status_response = json.loads(await websocket.recv())

        # Toggle the recording state based on the current status
        if recording_status_response['status'] == 'ok':
            if recording_status_response['isRecording']:
                stop_command = json.dumps({
                    "request-type": "StopRecording",
                    "message-id": "4"
                })
                await websocket.send(stop_command)
                print("Stopping recording:", json.loads(await websocket.recv()))
            else:
                start_command = json.dumps({
                    "request-type": "StartRecording",
                    "message-id": "5"
                })
                await websocket.send(start_command)
                print("Starting recording:", json.loads(await websocket.recv()))

async def main():
    await toggle_recording()

if __name__ == '__main__':
    asyncio.run(main())
