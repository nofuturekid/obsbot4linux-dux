import QtQuick
import QtMultimedia

// Live camera picture. Loaded by URL from PreviewPane, so a missing qt6-multimedia only
// disables the preview instead of breaking the whole popout.
Item {
    id: root

    // camera on; off keeps the device free for other apps
    property bool running: false

    // /dev/videoN of the camera to show (the by-id path from obsbot4linux, resolved)
    property string node: ""
    // Qt's device with that id; null shows nothing rather than another camera (e.g. a laptop's)
    readonly property var device: mediaDevices.videoInputs.find(d => String(d.id) === root.node) ?? null

    // When another preview (popout / desktop widget) hands the camera over, it may still hold the
    // device for a moment and the first start fails: retry a few times instead of staying black.
    property bool restarting: false
    property int retries: 0
    onRunningChanged: {
        retries = 0;
        hasFrame = false;
    }
    // A frame has arrived since the camera was switched on
    property bool hasFrame: false

    // A camera that was asleep (or is slow) may open without delivering frames: close and open
    // it again, a few times, like after an error
    Timer {
        id: frameWatch
        interval: 5000
        repeat: true
        running: root.running && !root.restarting && !root.hasFrame && root.device !== null
        onTriggered: {
            if (root.retries >= 10)
                return;
            root.retries++;
            root.restarting = true;
            retryTimer.restart();
        }
    }

    Timer {
        id: retryTimer
        interval: 300
        onTriggered: root.restarting = false
    }

    MediaDevices {
        id: mediaDevices
    }

    Loader {
        id: session
        anchors.fill: parent
        // The Camera object exists only while running: Qt keeps the device busy after
        // `active: false` until the Camera is destroyed
        active: root.running && !root.restarting && root.device !== null
        sourceComponent: Item {
            CaptureSession {
                camera: Camera {
                    cameraDevice: root.device
                    // 720p is plenty for a ~350 px preview and keeps MJPEG decoding cheap
                    cameraFormat: cameraDevice.videoFormats.find(f => f.resolution.width === 1280 && f.resolution.height === 720) ?? cameraDevice.videoFormats[0]
                    active: root.running && !root.restarting
                    // Not from inside the signal (binding loop): retry a moment later, the other
                    // preview may still be releasing the device
                    onErrorOccurred: (error, errorString) => {
                        console.warn("obsbot4linuxDux: preview camera:", errorString, "- retry", root.retries + 1);
                        if (!root.running || root.retries >= 10)
                            return;
                        root.retries++;
                        Qt.callLater(() => {
                            root.restarting = true;
                            retryTimer.restart();
                        });
                    }
                }
                videoOutput: videoOutput
            }

            VideoOutput {
                id: videoOutput
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
            }

            Connections {
                target: videoOutput.videoSink
                function onVideoFrameChanged() {
                    if (videoOutput.videoSink.videoFrame.isValid)
                        root.hasFrame = true;
                }
            }
        }
    }
}
