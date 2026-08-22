import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
    id: root

    moduleName: "marcelo.podcast"
    manageIpc: false

    readonly property var podcastService: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
    readonly property bool vertical: bar ? bar.vertical : false
    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property string currentTitle: podcastService && podcastService.currentEpisode ? podcastService.currentEpisode.title : "Podcast"
    readonly property string currentFeed: podcastService && podcastService.currentEpisode ? podcastService.currentEpisode.feedTitle : ""
    readonly property var visibleEpisodes: podcastService ? Model.filterEpisodes(podcastService.episodes, root.searchQuery, root.feedFilter) : []

    property string searchQuery: ""
    property string feedFilter: ""
    property int selectedIndex: 0
    property string activeTab: "episodes"

    function serviceCall(name) {
        if (!root.podcastService || typeof root.podcastService[name] !== "function")
            return false;
        return root.podcastService[name].apply(root.podcastService, Array.prototype.slice.call(arguments, 1));
    }

    function addFeed() {
        if (!feedUrlField.text.trim())
            return;
        if (root.serviceCall("addFeed", feedUrlField.text.trim())) {
            feedUrlField.text = "";
            feedUrlField.focus = false;
            keyCatcher.forceActiveFocus();
        }
    }

    function selectEpisode(delta) {
        if (root.activeTab !== "episodes")
            root.activeTab = "episodes";
        var count = root.visibleEpisodes.length;
        if (count === 0)
            return;
        root.selectedIndex = Math.max(0, Math.min(count - 1, root.selectedIndex + delta));
        root.scrollToSelection();
    }

    function scrollToSelection() {
        var target = Math.max(0, root.selectedIndex * Style.space(76) - episodesFlick.height / 3);
        var maximum = Math.max(0, episodesFlick.contentHeight - episodesFlick.height);
        episodesFlick.contentY = Math.min(maximum, target);
    }

    function activateSelection() {
        var episode = root.visibleEpisodes[root.selectedIndex];
        if (episode)
            root.serviceCall("playEpisode", episode);
    }

    function refresh() {
        root.serviceCall("refreshAll");
    }

    implicitWidth: vertical ? Style.bar.sizeVertical : Math.min(Style.space(180), row.implicitWidth + Style.space(18))
    implicitHeight: vertical ? row.implicitHeight + Style.space(8) : (bar ? bar.barSize : Style.bar.sizeHorizontal)

    onOpenedChanged: {
        if (!opened)
            return;
        root.selectedIndex = 0;
        Qt.callLater(function () {
            keyCatcher.forceActiveFocus();
        });
    }
    onVisibleEpisodesChanged: root.selectedIndex = Math.min(root.selectedIndex, Math.max(0, root.visibleEpisodes.length - 1))

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Style.space(6)

        Text {
            text: root.podcastService && root.podcastService.playback.playing ? ">" : "POD"
            color: root.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            visible: !root.vertical
            width: Math.min(Style.space(135), titleText.implicitWidth)
            height: titleText.implicitHeight
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            Text {
                id: titleText

                text: root.currentTitle
                color: root.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                root.toggle();
            else if (mouse.button === Qt.MiddleButton)
                root.serviceCall("playNext");
            else
                root.serviceCall("togglePlayPause");
        }
        onWheel: function (wheel) {
            if (wheel.angleDelta.y > 0)
                root.serviceCall("seek", -30);
            else if (wheel.angleDelta.y < 0)
                root.serviceCall("seek", 30);
        }
        onEntered: if (root.bar)
            root.bar.showTooltip(root, root.currentFeed ? root.currentFeed + " - " + root.currentTitle : root.currentTitle)
        onExited: if (root.bar)
            root.bar.hideTooltip(root)
    }

    KeyboardPanel {
        id: panel

        anchorItem: root
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(520))
        contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(680))

        PanelKeyCatcher {
            id: keyCatcher

            anchors.fill: parent
            blocked: feedUrlField.activeFocus || searchField.activeFocus
            onMoveRequested: function (dx, dy) {
                if (dy !== 0)
                    root.selectEpisode(dy);
                else if (dx !== 0)
                    root.serviceCall("seek", dx * 30);
            }
            onActivateRequested: root.activateSelection()
            onCloseRequested: root.close()
            onTabRequested: function (direction) {
                root.switchPanel(direction);
            }
            onTextKey: function (value) {
                if (value === "1") {
                    root.activeTab = "episodes";
                } else if (value === "2") {
                    root.activeTab = "feeds";
                } else if (value === "r" || value === "R") {
                    root.refresh();
                } else if (value === "p" || value === "P") {
                    root.serviceCall("togglePlayPause");
                } else if (value === "n" || value === "N") {
                    root.serviceCall("playNext");
                } else if (value === "b" || value === "B") {
                    root.serviceCall("playPrevious");
                } else if (value === "/") {
                    root.activeTab = "episodes";
                    searchField.forceActiveFocus();
                    searchField.selectAll();
                }
            }

            Flickable {
                id: contentFlick

                anchors.fill: parent
                contentWidth: width
                contentHeight: panelColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: panelColumn

                    width: contentFlick.width
                    spacing: Style.space(12)

                    Item {
                        width: parent.width
                        height: Math.max(heroImage.height, heroLabels.implicitHeight)

                        BorderSurface {
                            id: heroImage

                            width: Style.space(72)
                            height: width
                            radius: Style.cornerRadius
                            color: Style.selectedFillFor(root.foreground, Color.accent)
                            borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

                            Image {
                                id: heroArt

                                anchors.fill: parent
                                anchors.margins: Style.space(2)
                                source: root.podcastService && root.podcastService.currentEpisode ? root.podcastService.currentEpisode.artUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: source !== ""
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "POD"
                                color: root.foreground
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.title
                                font.bold: true
                                visible: !heroArt.visible
                            }
                        }

                        Column {
                            id: heroLabels

                            anchors.left: heroImage.right
                            anchors.leftMargin: Style.space(14)
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(3)

                            Text {
                                text: root.podcastService && root.podcastService.currentEpisode ? root.podcastService.currentEpisode.title : "No episode selected"
                                color: root.foreground
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.title
                                font.bold: true
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: root.currentFeed || "Add a feed in the Podcasts tab"
                                color: Qt.darker(root.foreground, 1.4)
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.bodySmall
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: root.podcastService && root.podcastService.currentEpisode ? Model.formatPosition(root.podcastService.playback.position, root.podcastService.playback.duration || root.podcastService.currentEpisode.duration) : ""
                                color: Qt.darker(root.foreground, 1.5)
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.caption
                                visible: text !== ""
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Style.space(5)
                        color: Style.selectedFillFor(root.foreground, Color.accent)

                        Rectangle {
                            width: root.podcastService && root.podcastService.currentEpisode ? parent.width * Model.progressRatio(root.podcastService.currentEpisode, root.podcastService.progress) : 0
                            height: parent.height
                            color: root.foreground
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Style.space(5)

                        Button {
                            text: "-30"
                            foreground: root.foreground
                            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                            onClicked: root.serviceCall("seek", -30)
                        }

                        Button {
                            text: root.podcastService && root.podcastService.playback.playing ? "Pause" : "Play"
                            foreground: root.foreground
                            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                            onClicked: root.serviceCall("togglePlayPause")
                        }

                        Button {
                            text: "+30"
                            foreground: root.foreground
                            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                            onClicked: root.serviceCall("seek", 30)
                        }

                        Button {
                            text: "Next"
                            foreground: root.foreground
                            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                            onClicked: root.serviceCall("playNext")
                        }
                    }

                    ButtonGroup {
                        id: tabBar

                        options: [
                            {
                                "value": "episodes",
                                "label": "Episodes"
                            },
                            {
                                "value": "feeds",
                                "label": "Podcasts"
                            }
                        ]
                        value: root.activeTab
                        foreground: root.foreground
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        onChanged: function (value) {
                            root.activeTab = value;
                        }
                    }

                    Column {
                        id: episodesPane

                        width: parent.width
                        spacing: Style.space(12)
                        visible: root.activeTab === "episodes"

                        TextField {
                            id: searchField

                            width: parent.width
                            placeholderText: "Search episodes (press /)"
                            foreground: root.foreground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            onTextChanged: {
                                root.searchQuery = text;
                                root.selectedIndex = 0;
                            }
                        }

                        Button {
                            visible: root.feedFilter !== ""
                            text: "Show all episodes"
                            foreground: root.foreground
                            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                            onClicked: root.feedFilter = ""
                        }

                        PanelSectionHeader {
                            text: "EPISODES"
                            foreground: root.foreground
                            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        }

                        Flickable {
                            id: episodesFlick

                            width: parent.width
                            height: Math.min(Style.space(330), Math.max(Style.space(90), episodesColumn.implicitHeight))
                            contentWidth: width
                            contentHeight: episodesColumn.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: contentHeight > height

                            Column {
                                id: episodesColumn

                                width: episodesFlick.width
                                spacing: Style.space(4)

                                Repeater {
                                    model: root.visibleEpisodes

                                    BorderSurface {
                                        required property var modelData
                                        required property int index

                                        readonly property var episodeProgress: root.podcastService ? Model.progressFor(root.podcastService.progress, modelData.key) : ({
                                                position: 0,
                                                completed: false
                                            })
                                        readonly property real ratio: root.podcastService ? Model.progressRatio(modelData, root.podcastService.progress) : 0

                                        width: episodesColumn.width
                                        implicitHeight: episodeColumn.implicitHeight + Style.space(12)
                                        radius: Style.cornerRadius
                                        color: index === root.selectedIndex ? Style.selectedFillFor(root.foreground, Color.accent) : "transparent"
                                        borderSpec: index === root.selectedIndex ? Border.controlSpec("normal", root.foreground, Color.accent) : Border.none()

                                        Column {
                                            id: episodeColumn

                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: Style.space(8)
                                            anchors.rightMargin: Style.space(8)
                                            spacing: Style.space(2)

                                            Text {
                                                text: modelData.title
                                                color: root.foreground
                                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                                font.pixelSize: Style.font.body
                                                font.bold: index === root.selectedIndex
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }

                                            Text {
                                                text: modelData.feedTitle + "  " + Model.formatDate(modelData.publishedAt) + (modelData.duration > 0 ? "  " + Model.formatDuration(modelData.duration) : "") + (episodeProgress.completed ? "  DONE" : "")
                                                color: Qt.darker(root.foreground, 1.5)
                                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                                font.pixelSize: Style.font.caption
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }

                                            Rectangle {
                                                width: parent.width
                                                height: Style.space(3)
                                                color: Style.selectedFillFor(root.foreground, Color.accent)
                                                visible: ratio > 0

                                                Rectangle {
                                                    width: parent.width * ratio
                                                    height: parent.height
                                                    color: root.foreground
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton
                                            onClicked: {
                                                root.selectedIndex = index;
                                                root.serviceCall("playEpisode", modelData);
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: root.visibleEpisodes.length === 0
                                    text: root.podcastService && root.podcastService.hasFeeds ? "No playable episodes match this filter." : "Add a podcast feed in the Podcasts tab."
                                    color: Qt.darker(root.foreground, 1.4)
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: Style.font.bodySmall
                                    font.italic: true
                                }
                            }
                        }
                    }

                    Column {
                        id: feedsPane

                        width: parent.width
                        spacing: Style.space(12)
                        visible: root.activeTab === "feeds"

                        PanelSectionHeader {
                            text: "PODCASTS"
                            foreground: root.foreground
                            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        }

                        Row {
                            width: parent.width
                            spacing: Style.space(6)

                            TextField {
                                id: feedUrlField

                                width: parent.width - addFeedButton.width - parent.spacing
                                placeholderText: "Paste an RSS or Atom feed URL"
                                foreground: root.foreground
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                onAccepted: root.addFeed()
                            }

                            Button {
                                id: addFeedButton

                                text: "Add"
                                foreground: root.foreground
                                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                                onClicked: root.addFeed()
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Style.space(4)

                            Repeater {
                                model: root.podcastService ? root.podcastService.feeds : []

                                BorderSurface {
                                    required property var modelData
                                    required property int index

                                    width: parent.width
                                    implicitHeight: feedRow.implicitHeight + Style.space(10)
                                    radius: Style.cornerRadius
                                    color: root.feedFilter === modelData.url ? Style.selectedFillFor(root.foreground, Color.accent) : "transparent"
                                    borderSpec: root.feedFilter === modelData.url ? Border.controlSpec("normal", root.foreground, Color.accent) : Border.none()

                                    Row {
                                        id: feedRow

                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: Style.space(8)
                                        anchors.rightMargin: Style.space(4)
                                        spacing: Style.space(6)

                                        Column {
                                            width: parent.width - removeFeedButton.width - parent.spacing
                                            spacing: Style.space(1)

                                            Text {
                                                text: modelData.title
                                                color: root.foreground
                                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                                font.pixelSize: Style.font.body
                                                font.bold: root.feedFilter === modelData.url
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }

                                            Text {
                                                text: modelData.error || modelData.url
                                                color: modelData.error ? Color.urgent : Qt.darker(root.foreground, 1.6)
                                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                                font.pixelSize: Style.font.caption
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }
                                        }

                                        PanelActionButton {
                                            id: removeFeedButton

                                            iconText: "x"
                                            tooltipText: "Remove feed"
                                            foreground: root.foreground
                                            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                                            hoverColor: Color.urgent
                                            onClicked: root.serviceCall("removeFeed", modelData.url)
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        z: -1
                                        acceptedButtons: Qt.LeftButton
                                        onClicked: {
                                            var nextFilter = root.feedFilter === modelData.url ? "" : modelData.url;
                                            root.feedFilter = nextFilter;
                                            if (nextFilter !== "")
                                                root.activeTab = "episodes";
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: root.podcastService && !root.podcastService.hasFeeds
                                text: "Paste a feed URL above to subscribe."
                                color: Qt.darker(root.foreground, 1.4)
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.bodySmall
                                font.italic: true
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Style.space(6)

                            Button {
                                text: "Refresh"
                                foreground: root.foreground
                                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                                onClicked: root.refresh()
                            }
                        }
                    }

                    Text {
                        text: root.podcastService && root.podcastService.errorText ? root.podcastService.errorText : (root.podcastService ? root.podcastService.statusText : "Starting podcast service...")
                        color: root.podcastService && root.podcastService.errorText ? Color.urgent : Qt.darker(root.foreground, 1.4)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.Wrap
                        width: parent.width
                        visible: text !== ""
                    }

                    Text {
                        text: root.activeTab === "episodes" ? "Keys: j/k select  Enter play  h/l seek  / search  1/2 tab" : "Keys: r refresh  1/2 tab"
                        color: Qt.darker(root.foreground, 1.7)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }
            }
        }
    }
}
