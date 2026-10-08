###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "StoryRowCtrl", ->
    provide = null
    controller = null
    mocks = {}

    _mockTgProjectService = () ->
        mocks.tgProjectService = {
            activeMembers: Immutable.fromJS([
                {id: 1, full_name_display: "Member 1"},
                {id: 2, full_name_display: "Member 2"},
                {id: 3, full_name_display: "Member 3"}
            ])
        }
        provide.value "tgProjectService", mocks.tgProjectService

    _mockTgAvatarService = () ->
        mocks.tgAvatarService = {
            getAvatar: sinon.stub().returns({url: "avatar"})
        }
        provide.value "tgAvatarService", mocks.tgAvatarService

    _mockTranslate = () ->
        mocks.translate = {
            instant: sinon.stub().returnsArg(0)
        }
        provide.value "$translate", mocks.translate

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockTgProjectService()
            _mockTgAvatarService()
            _mockTranslate()
            return null

    beforeEach ->
        module "taigaEpics"

        _mocks()

        inject ($controller) ->
            controller = $controller

    it "calculate percentage from the server done percent", () ->
        data = {
            story: Immutable.fromJS(
                completion_percent_done: 60,
                tasks: [
                    {is_closed: true},
                    {is_closed: true},
                    {is_closed: true},
                    {is_closed: false},
                    {is_closed: false},
                ]
            )
        }

        ctrl = controller "StoryRowCtrl", null, data
        expect(ctrl.donePercentage).to.be.equal("60%")
        expect(ctrl.progressPercentage).to.be.equal("0%")
        expect(ctrl.segments.length).to.be.equal(1)
        expect(ctrl.segments[0].type).to.be.equal("done")
        expect(ctrl.segments[0].width).to.be.equal("60%")
        expect(ctrl.segments[0].name).to.be.equal("EPICS.DONE")

    it "calculate percentage for closed story", () ->
        data = {
            story: Immutable.fromJS(
                completion_percent_done: 100,
                tasks: [
                    {is_closed: true},
                    {is_closed: true},
                    {is_closed: true},
                    {is_closed: false},
                    {is_closed: false},
                ]
                is_closed: true
            )
        }

        ctrl = controller "StoryRowCtrl", null, data
        expect(ctrl.donePercentage).to.be.equal("100%")
        expect(ctrl.progressPercentage).to.be.equal("0%")

    it "calculate percentage for story with no tasks", () ->
        data = {
            story: Immutable.fromJS(
                tasks: []
            )
        }

        ctrl = controller "StoryRowCtrl", null, data
        expect(ctrl.donePercentage).to.be.equal("0%")
        expect(ctrl.progressPercentage).to.be.equal("0%")
        expect(ctrl.segments.length).to.be.equal(1)
        expect(ctrl.segments[0].type).to.be.equal("empty")
        expect(ctrl.segments[0].name).to.be.equal("EPICS.NOT_STARTED")

    it "use completion fields when available", () ->
        data = {
            story: Immutable.fromJS(
                completion_percent_done: 50,
                completion_percent_progress: 25,
                tasks: [
                    {is_closed: true},
                    {is_closed: false}
                ]
            )
        }

        ctrl = controller "StoryRowCtrl", null, data
        expect(ctrl.donePercentage).to.be.equal("50%")
        expect(ctrl.progressPercentage).to.be.equal("25%")
        expect(ctrl.segments.length).to.be.equal(2)
        expect(ctrl.segments[1].type).to.be.equal("progress")
        expect(ctrl.segments[1].left).to.be.equal("50%")
        expect(ctrl.segments[0].name).to.be.equal("EPICS.DONE")
        expect(ctrl.segments[1].name).to.be.equal("EPICS.PROGRESS")

    it "ignore tasks status when the server sends no percentages", () ->
        data = {
            story: Immutable.fromJS(
                tasks: [
                    {is_closed: true},
                    {is_closed: true},
                    {is_closed: true},
                    {is_closed: false},
                    {is_closed: false},
                ]
            )
        }

        ctrl = controller "StoryRowCtrl", null, data
        expect(ctrl.donePercentage).to.be.equal("0%")
        expect(ctrl.progressPercentage).to.be.equal("0%")

    it "calculate tasks info correctly", () ->
        data = {
            story: Immutable.fromJS(
                tasks: [
                    {is_closed: true},
                    {is_closed: true},
                    {is_closed: false},
                    {is_closed: false}
                ]
            )
        }

        ctrl = controller "StoryRowCtrl", null, data
        expect(ctrl.tasksInfo).to.be.equal("EPICS.TASKS_INFO")
        expect(mocks.translate.instant).to.be.calledWith("EPICS.TASKS_INFO", {completed: 2, total: 4})

    it "calculate tasks info for story with no tasks", () ->
        data = {
            story: Immutable.fromJS(
                tasks: []
            )
        }

        ctrl = controller "StoryRowCtrl", null, data
        expect(ctrl.tasksInfo).to.be.equal("EPICS.TASKS_INFO")
        expect(mocks.translate.instant).to.be.calledWith("EPICS.TASKS_INFO", {completed: 0, total: 0})

    it "display avatars of the assigned users", () ->
        data = {
            story: Immutable.fromJS(
                assigned_to: 1,
                assigned_users: [1, 2],
                tasks: []
            )
        }

        ctrl = controller "StoryRowCtrl", null, data
        expect(ctrl.assignedUsersDisplay.length).to.be.equal(2)
        expect(ctrl.extraAssigneesCount).to.be.equal(0)
        expect(mocks.tgAvatarService.getAvatar.callCount).to.be.equal(2)

    it "count extra assignees when more than two users are assigned", () ->
        data = {
            story: Immutable.fromJS(
                assigned_to: 1,
                assigned_users: [1, 2, 3],
                tasks: []
            )
        }

        ctrl = controller "StoryRowCtrl", null, data
        expect(ctrl.assignedUsersDisplay.length).to.be.equal(1)
        expect(ctrl.extraAssigneesCount).to.be.equal(2)

    it "show the empty state when the primary assignee is not an active member, ignoring assigned_to_extra_info", () ->
        data = {
            story: Immutable.fromJS(
                assigned_to: 99,
                assigned_to_extra_info: {id: 99, full_name_display: "Former member"},
                assigned_users: [99],
                tasks: []
            )
        }

        ctrl = controller "StoryRowCtrl", null, data
        expect(ctrl.assignedUsersDisplay).to.be.eql([])
        expect(ctrl.extraAssigneesCount).to.be.equal(0)
        expect(mocks.tgAvatarService.getAvatar.callCount).to.be.equal(0)

    it "show the empty state when assigned_users is empty even if assigned_to_extra_info is present", () ->
        data = {
            story: Immutable.fromJS(
                assigned_to: 1,
                assigned_to_extra_info: {id: 1, full_name_display: "Member 1"},
                assigned_users: [],
                tasks: []
            )
        }

        ctrl = controller "StoryRowCtrl", null, data
        expect(ctrl.assignedUsersDisplay).to.be.eql([])
        expect(ctrl.extraAssigneesCount).to.be.equal(0)
        expect(mocks.tgAvatarService.getAvatar.callCount).to.be.equal(0)

    it "discard assigned users that are not active members and count only the resolved ones", () ->
        data = {
            story: Immutable.fromJS(
                assigned_to: 1,
                assigned_users: [1, 99, 2, 98],
                tasks: []
            )
        }

        ctrl = controller "StoryRowCtrl", null, data
        expect(ctrl.assignedUsersDisplay.length).to.be.equal(2)
        expect(ctrl.extraAssigneesCount).to.be.equal(0)
        expect(mocks.tgAvatarService.getAvatar.callCount).to.be.equal(2)

    it "show the assigned users in ascending id order", () ->
        data = {
            story: Immutable.fromJS(
                assigned_users: [3, 1],
                tasks: []
            )
        }

        ctrl = controller "StoryRowCtrl", null, data
        expect(ctrl.assignedUsersDisplay.length).to.be.equal(2)
        expect(mocks.tgAvatarService.getAvatar.firstCall.args[0].get('id')).to.be.equal(1)
        expect(mocks.tgAvatarService.getAvatar.secondCall.args[0].get('id')).to.be.equal(3)

    it "count extra assignees only among the resolved members", () ->
        data = {
            story: Immutable.fromJS(
                assigned_to: 1,
                assigned_users: [1, 2, 3, 99],
                tasks: []
            )
        }

        ctrl = controller "StoryRowCtrl", null, data
        expect(ctrl.assignedUsersDisplay.length).to.be.equal(1)
        expect(ctrl.extraAssigneesCount).to.be.equal(2)

    it "leave assigned users empty when nobody is assigned", () ->
        data = {
            story: Immutable.fromJS(
                tasks: []
            )
        }

        ctrl = controller "StoryRowCtrl", null, data
        expect(ctrl.assignedUsersDisplay).to.be.eql([])
        expect(ctrl.extraAssigneesCount).to.be.equal(0)
        expect(mocks.tgAvatarService.getAvatar.callCount).to.be.equal(0)
