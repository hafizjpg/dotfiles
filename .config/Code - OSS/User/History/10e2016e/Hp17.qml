import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls

PopupWindow {
    id: wallpaperPicker

    // Toggle visibility state
    property bool isOpen: false
    visible: isOpen

    // Configure your wallpaper directory path here
    readonly property string wallpaperDir: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers/"
    readonly property string rawDir: Quickshell.env("HOME") + "/Wallpapers"

    // Window dimensions and positioning
    width: 680
    height: 440
    color: "transparent"

    anchor {
        window: Quickshell.screens[0]
        rect.x: (Quickshell.screens[0].width - width) / 2
        rect.y: (Quickshell.screens[0].height - height) / 2
    }

    // Palette Matching your Bar
    readonly property color surface: "#1C1E26"
    readonly property color surfaceHighlight: "#2D303E"
    readonly property color accent: "#7C4DFF"
    readonly property color ink: "#F3F4F6"
    readonly property color inkDim: "#9CA3AF"
    readonly property color borderOutline: "#2AFFFFFF"

    // Model storing scanned wallpaper filenames
    ListModel {
        id: wallpaperModel
    }

    // Scanner Process: Lists PNG, JPG, JPEG, and WEBP files from your wallpaper folder
    Process {
        id: scanProc
        command: ["bash", "-c", "ls -1 \"" + wallpaperPicker.rawDir + "\" | grep -E '\\.(jpg|jpeg|png|webp)$'"]
        stdout: SplitParser {
            onRead: data => {
                const filename = data.trim();
                if (filename.length > 0) {
                    wallpaperModel.append({ "fileName": filename });
                }
            }
        }
    }

    // Process to apply wallpaper using awww
    Process {
        id: setWallpaperProc
        command: ["true"]
    }

    function applyWallpaper(filePath) {
        setWallpaperProc.command = ["awww", "img", filePath, "--transition-type", "grow", "--transition-fps", "60"];
        setWallpaperProc.running = true;
    }

    function scanWallpapers() {
        wallpaperModel.clear();
        if (!scanProc.running) {
            scanProc.running = true;
        }
    }

    Component.onCompleted: scanWallpapers()

    // --- Main Panel Container ---
    Rectangle {
        anchors.fill: parent
        radius: 20
        color: wallpaperPicker.surface
        border.width: 1
        border.color: wallpaperPicker.borderOutline

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header Section
            Row {
                width: parent.width
                height: 32

                Text {
                    text: "\uf03e  Wallpaper Picker"
                    color: wallpaperPicker.ink
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { Layout.fillWidth: true; width: parent.width - 250 }

                // Refresh Button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 8
                    color: refreshHover.containsMouse ? wallpaperPicker.surfaceHighlight : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "\uf021"
                        color: wallpaperPicker.inkDim
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: refreshHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: wallpaperPicker.scanWallpapers()
                    }
                }

                // Close Button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 8
                    color: closeHover.containsMouse ? "#FF5555" : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        color: wallpaperPicker.ink
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: wallpaperPicker.isOpen = false
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: wallpaperPicker.borderOutline
            }

            // Thumbnail Grid
            GridView {
                id: grid
                width: parent.width
                height: parent.height - 60
                cellWidth: 210
                cellHeight: 130
                clip: true

                model: wallpaperModel

                delegate: Item {
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: 12
                        color: itemHover.containsMouse ? wallpaperPicker.surfaceHighlight : "transparent"
                        border.width: itemHover.containsMouse ? 2 : 1
                        border.color: itemHover.containsMouse ? wallpaperPicker.accent : wallpaperPicker.borderOutline

                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Image {
                            id: thumb
                            anchors.fill: parent
                            anchors.margins: 4
                            source: wallpaperPicker.wallpaperDir + model.fileName
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            mipmap: true

                            // Rounded corners clip for thumbnails
                            layer.enabled: true
                        }

                        // Gradient overlay for text legibility
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 28
                            radius: 10
                            color: "#CC111318"

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 12
                                text: model.fileName
                                color: wallpaperPicker.ink
                                font.pixelSize: 9
                                font.family: "JetBrainsMono Nerd Font"
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            id: itemHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                const fullPath = wallpaperPicker.rawDir + "/" + model.fileName;
                                wallpaperPicker.applyWallpaper(fullPath);
                            }
                        }
                    }
                }
            }
        }
    }
}