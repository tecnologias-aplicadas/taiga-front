###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "RelatedUserstoryRow", ->
    RelatedUserstoryRowCtrl =  null
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

    _mockTgConfirm = () ->
        mocks.tgConfirm = {
            askOnDelete: sinon.stub()
            notify: sinon.stub()
        }

        provide.value "$tgConfirm", mocks.tgConfirm

    _mockTgAvatarService = () ->
        mocks.tgAvatarService = {
            getAvatar: sinon.stub()
        }

        provide.value "tgAvatarService", mocks.tgAvatarService

    _mockTranslate = () ->
        mocks.translate = {
            instant: sinon.stub()
        }

        provide.value "$translate", mocks.translate

    _mockTgResources = () ->
        mocks.tgResources = {
            epics: {
                deleteRelatedUserstory: sinon.stub()
            }
        }

        provide.value "tgResources", mocks.tgResources

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockTgProjectService()
            _mockTgConfirm()
            _mockTgAvatarService()
            _mockTranslate()
            _mockTgResources()

            return null

    beforeEach ->
        module "taigaEpics"

        _mocks()

        inject ($controller) ->
            controller = $controller

        RelatedUserstoryRowCtrl = controller "RelatedUserstoryRowCtrl"

    it "set avatar data from the assigned users", (done) ->
        RelatedUserstoryRowCtrl.userstory = Immutable.fromJS({
            assigned_users: [3]
        })
        member = mocks.tgProjectService.activeMembers.get(2)
        avatar = {
            url: "http://taiga.io"
            bg: "#AAAAAA"
        }
        mocks.tgAvatarService.getAvatar.withArgs(member).returns(avatar)
        RelatedUserstoryRowCtrl.setAvatarData()
        expect(mocks.tgAvatarService.getAvatar).have.been.calledWith(member)
        expect(RelatedUserstoryRowCtrl.avatar).is.equal(avatar)
        done()

    it "get assigned to full name display for an assigned active member", (done) ->
        RelatedUserstoryRowCtrl.userstory = Immutable.fromJS({
            assigned_users: [1]
        })

        expect(RelatedUserstoryRowCtrl.getAssignedToFullNameDisplay()).is.equal("Member 1")
        done()

    it "pick the assigned user with the lowest id when there are several", (done) ->
        RelatedUserstoryRowCtrl.userstory = Immutable.fromJS({
            assigned_users: [3, 1, 2]
        })
        member = mocks.tgProjectService.activeMembers.get(0)
        avatar = {url: "http://taiga.io", fullName: "Member 1"}
        mocks.tgAvatarService.getAvatar.withArgs(member).returns(avatar)

        RelatedUserstoryRowCtrl.setAvatarData()

        expect(mocks.tgAvatarService.getAvatar).have.been.calledWith(member)
        expect(RelatedUserstoryRowCtrl.getAssignedToFullNameDisplay()).is.equal("Member 1")
        done()

    describe "extra assignees marker", () ->
        _setAvatarFor = (assignedUsers) ->
            RelatedUserstoryRowCtrl.userstory = Immutable.fromJS({
                assigned_users: assignedUsers
            })
            mocks.tgAvatarService.getAvatar.returns({url: "http://taiga.io"})
            RelatedUserstoryRowCtrl.setAvatarData()
            return RelatedUserstoryRowCtrl.extraAssigneesCount

        it "is zero with a single assigned user", () ->
            expect(_setAvatarFor([1])).to.be.equal(0)

        it "is zero without assigned users", () ->
            expect(_setAvatarFor([])).to.be.equal(0)

        it "counts one extra with two assigned users", () ->
            expect(_setAvatarFor([1, 2])).to.be.equal(1)

        it "counts two extra with three assigned users", () ->
            expect(_setAvatarFor([1, 2, 3])).to.be.equal(2)

        it "does not count assigned users that are not active members", () ->
            expect(_setAvatarFor([1, 2, 99])).to.be.equal(1)

    it "ignore assigned_to_extra_info when assigned_users is empty", (done) ->
        RelatedUserstoryRowCtrl.userstory = Immutable.fromJS({
            assigned_to: 1
            assigned_to_extra_info: {
                id: 1
                full_name_display: "Member 1"
            }
            assigned_users: []
        })
        avatar = {url: "http://taiga.io/unnamed.png"}
        mocks.tgAvatarService.getAvatar.withArgs(null).returns(avatar)
        mocks.translate.instant.withArgs("COMMON.ASSIGNED_TO.NOT_ASSIGNED").returns("Unassigned")

        RelatedUserstoryRowCtrl.setAvatarData()

        expect(mocks.tgAvatarService.getAvatar).have.been.calledWith(null)
        expect(RelatedUserstoryRowCtrl.avatar).is.equal(avatar)
        expect(RelatedUserstoryRowCtrl.getAssignedToFullNameDisplay()).is.equal("Unassigned")
        done()

    it "get assigned to full name display for unassigned user story", (done) ->
        RelatedUserstoryRowCtrl.userstory = Immutable.fromJS({
            assigned_to: null
        })
        mocks.translate.instant.withArgs("COMMON.ASSIGNED_TO.NOT_ASSIGNED").returns("Unassigned")
        expect(RelatedUserstoryRowCtrl.getAssignedToFullNameDisplay()).is.equal("Unassigned")
        done()

    it "show the first assigned user when the story was promoted without assigned_to", (done) ->
        RelatedUserstoryRowCtrl.userstory = Immutable.fromJS({
            assigned_to: null
            assigned_to_extra_info: null
            assigned_users: [2]
        })
        member = mocks.tgProjectService.activeMembers.get(1)
        avatar = {
            url: "http://taiga.io"
            bg: "#AAAAAA"
            fullName: "Member 2"
        }
        mocks.tgAvatarService.getAvatar.withArgs(member).returns(avatar)

        RelatedUserstoryRowCtrl.setAvatarData()

        expect(mocks.tgAvatarService.getAvatar).have.been.calledWith(member)
        expect(RelatedUserstoryRowCtrl.avatar).is.equal(avatar)
        expect(RelatedUserstoryRowCtrl.getAssignedToFullNameDisplay()).is.equal("Member 2")
        done()

    it "show the empty state when the assigned user is no longer an active member", (done) ->
        RelatedUserstoryRowCtrl.userstory = Immutable.fromJS({
            assigned_to: null
            assigned_to_extra_info: null
            assigned_users: [99]
        })
        avatar = {url: "http://taiga.io/unnamed.png"}
        mocks.tgAvatarService.getAvatar.withArgs(null).returns(avatar)
        mocks.translate.instant.withArgs("COMMON.ASSIGNED_TO.NOT_ASSIGNED").returns("Unassigned")

        RelatedUserstoryRowCtrl.setAvatarData()

        expect(mocks.tgAvatarService.getAvatar).have.been.calledWith(null)
        expect(RelatedUserstoryRowCtrl.avatar).is.equal(avatar)
        expect(RelatedUserstoryRowCtrl.getAssignedToFullNameDisplay()).is.equal("Unassigned")
        done()

    it "show the empty state when assigned_users is empty", (done) ->
        RelatedUserstoryRowCtrl.userstory = Immutable.fromJS({
            assigned_to: null
            assigned_to_extra_info: null
            assigned_users: []
        })
        avatar = {url: "http://taiga.io/unnamed.png"}
        mocks.tgAvatarService.getAvatar.withArgs(null).returns(avatar)
        mocks.translate.instant.withArgs("COMMON.ASSIGNED_TO.NOT_ASSIGNED").returns("Unassigned")

        RelatedUserstoryRowCtrl.setAvatarData()

        expect(mocks.tgAvatarService.getAvatar).have.been.calledWith(null)
        expect(RelatedUserstoryRowCtrl.avatar).is.equal(avatar)
        expect(RelatedUserstoryRowCtrl.getAssignedToFullNameDisplay()).is.equal("Unassigned")
        done()

    it "delete related userstory success", (done) ->
        RelatedUserstoryRowCtrl.epic = Immutable.fromJS({
            subject: "SampleEpic"
            id: 123
        })
        RelatedUserstoryRowCtrl.userstory = Immutable.fromJS({
            subject: "Deleting"
            id: 124
        })

        RelatedUserstoryRowCtrl.loadRelatedUserstories = sinon.stub()

        askResponse = {
            finish: sinon.spy()
        }

        mocks.translate.instant.withArgs("LIGHTBOX.REMOVE_RELATIONSHIP_WITH_EPIC.TITLE").returns("title")
        mocks.translate.instant.withArgs("LIGHTBOX.REMOVE_RELATIONSHIP_WITH_EPIC.MESSAGE", {epicSubject: "SampleEpic"}).returns("message")

        mocks.tgConfirm.ask = sinon.stub()
        mocks.tgConfirm.ask.withArgs("title").promise().resolve(askResponse)

        promise = mocks.tgResources.epics.deleteRelatedUserstory.withArgs(123, 124).promise().resolve(true)
        RelatedUserstoryRowCtrl.onDeleteRelatedUserstory().then () ->
            expect(RelatedUserstoryRowCtrl.loadRelatedUserstories).have.been.calledOnce
            expect(askResponse.finish).have.been.calledOnce
            done()

    it "delete related userstory error", (done) ->
        RelatedUserstoryRowCtrl.epic = Immutable.fromJS({
            epicSubject: "SampleEpic"
            id: 123
        })
        RelatedUserstoryRowCtrl.userstory = Immutable.fromJS({
            subject: "Deleting"
            id: 124
        })

        RelatedUserstoryRowCtrl.loadRelatedUserstories = sinon.stub()

        askResponse = {
            finish: sinon.spy()
        }

        mocks.translate.instant.withArgs("LIGHTBOX.REMOVE_RELATIONSHIP_WITH_EPIC.TITLE").returns("title")
        mocks.translate.instant.withArgs("LIGHTBOX.REMOVE_RELATIONSHIP_WITH_EPIC.MESSAGE", {epicSubject: "SampleEpic"}).returns("message")
        mocks.translate.instant.withArgs("EPIC.ERROR_UNLINK_RELATED_USERSTORY").returns("error message")

        mocks.tgConfirm.ask = sinon.stub()
        mocks.tgConfirm.ask.withArgs("title").promise().resolve(askResponse)

        promise = mocks.tgResources.epics.deleteRelatedUserstory.withArgs(123, 124).promise().reject(new Error("error"))
        RelatedUserstoryRowCtrl.onDeleteRelatedUserstory().then () ->
            expect(RelatedUserstoryRowCtrl.loadRelatedUserstories).to.not.have.been.called
            expect(askResponse.finish).have.been.calledWith(false)
            expect(mocks.tgConfirm.notify).have.been.calledWith("error", null, "error message")
            done()
