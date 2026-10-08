###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "EpicRow", ->
    epicRowCtrl =  null
    provide = null
    controller = null
    scope = null
    mocks = {}

    _mockTgConfirm = () ->
        mocks.tgConfirm = {
            notify: sinon.stub()
        }
        provide.value "$tgConfirm", mocks.tgConfirm

    _mockTgProjectService = () ->
        mocks.tgProjectService = {
            project: {
                toJS: sinon.stub()
            }
            hasPermission: sinon.stub()
        }
        provide.value "tgProjectService", mocks.tgProjectService

    _mockTgEpicsService = () ->
        mocks.tgEpicsService = {
            listRelatedUserStories: sinon.stub()
            updateEpicStatus: sinon.stub()
            updateEpicAssignedTo: sinon.stub()
        }
        provide.value "tgEpicsService", mocks.tgEpicsService

    _mockTranslate = () ->
        mocks.translate = {
            instant: sinon.stub().returnsArg(0)
        }
        provide.value "$translate", mocks.translate

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockTgConfirm()
            _mockTgProjectService()
            _mockTgEpicsService()
            _mockTranslate()
            return null

    beforeEach ->
        module "taigaEpics"

        _mocks()

        inject ($controller, $rootScope) ->
            controller = $controller
            scope = $rootScope.$new()

    it "calculate progress bar with done and progress percent", () ->
        ctrl = controller "EpicRowCtrl", {$scope: scope}, {
            epic: Immutable.fromJS({
                completion_percent_done: 50
                completion_percent_progress: 25
            })
        }

        expect(ctrl.segments.length).to.be.equal(2)
        expect(ctrl.segments[0].type).to.be.equal("done")
        expect(ctrl.segments[0].width).to.be.equal("50%")
        expect(ctrl.segments[0].percentage).to.be.equal("50.00")
        expect(ctrl.segments[1].type).to.be.equal("progress")
        expect(ctrl.segments[1].width).to.be.equal("25%")
        expect(ctrl.segments[1].left).to.be.equal("50%")

    it "calculate progress bar in zero percent", () ->
        ctrl = controller "EpicRowCtrl", {$scope: scope}, {
            epic: Immutable.fromJS({
                completion_percent_done: 0
                completion_percent_progress: 0
            })
        }

        expect(ctrl.segments.length).to.be.equal(1)
        expect(ctrl.segments[0].type).to.be.equal("empty")
        expect(ctrl.segments[0].width).to.be.equal("100%")
        expect(ctrl.segments[0].percentage).to.be.equal("0.00")

    it "calculate progress bar in completed epic", () ->
        ctrl = controller "EpicRowCtrl", {$scope: scope}, {
            epic: Immutable.fromJS({
                completion_percent_done: 100
            })
        }

        expect(ctrl.segments.length).to.be.equal(1)
        expect(ctrl.segments[0].type).to.be.equal("done")
        expect(ctrl.segments[0].width).to.be.equal("100%")
        expect(ctrl.segments[0].percentage).to.be.equal("100.00")

    it "recalculate progress bar when the epic percent changes", () ->
        ctrl = controller "EpicRowCtrl", {$scope: scope}, {
            epic: Immutable.fromJS({
                completion_percent_done: 0
                completion_percent_progress: 0
            })
        }

        expect(ctrl.segments[0].type).to.be.equal("empty")

        ctrl.epic = ctrl.epic.set("completion_percent_done", 30)
        scope.$digest()

        expect(ctrl.segments.length).to.be.equal(1)
        expect(ctrl.segments[0].type).to.be.equal("done")
        expect(ctrl.segments[0].width).to.be.equal("30%")

    it "Update Epic Status Success", (done) ->
        ctrl = controller "EpicRowCtrl", {$scope: scope}, {
            epic: Immutable.fromJS({
                id: 1
                version: 1
            })
        }

        statusId = 1

        promise = mocks.tgEpicsService.updateEpicStatus
            .withArgs(ctrl.epic, statusId)
            .promise()
            .resolve()

        ctrl.loadingStatus = true
        ctrl.displayStatusList = true

        ctrl.updateStatus(statusId).then () ->
            expect(ctrl.loadingStatus).to.be.false
            expect(ctrl.displayStatusList).to.be.false
            done()

    it "Update Epic Status Error", (done) ->
        ctrl = controller "EpicRowCtrl", {$scope: scope}, {
            epic: Immutable.fromJS({
                id: 1
                version: 1
            })
        }

        statusId = 1

        promise = mocks.tgEpicsService.updateEpicStatus
            .withArgs(ctrl.epic, statusId)
            .promise()
            .reject(new Error('error'))

        ctrl.updateStatus(statusId).then () ->
            expect(ctrl.loadingStatus).to.be.false
            expect(ctrl.displayStatusList).to.be.false
            expect(mocks.tgConfirm.notify).have.been.calledWith('error')
            done()

    it "display User Stories", (done) ->
        ctrl = controller "EpicRowCtrl", {$scope: scope}, {
            epic: Immutable.fromJS({
                id: 1
            })
        }

        ctrl.displayUserStories = false

        data = Immutable.List()

        promise = mocks.tgEpicsService.listRelatedUserStories
            .withArgs(ctrl.epic)
            .promise()
            .resolve(data)

        ctrl.toggleUserStoryList().then () ->
            expect(ctrl.displayUserStories).to.be.true
            expect(ctrl.epicStories).is.equal(data)
            done()

    it "recarga da lista por evento do servidor atualiza as histórias expandidas", (done) ->
        ctrl = controller "EpicRowCtrl", {$scope: scope}, {
            epic: Immutable.fromJS({
                id: 1
            })
        }
        ctrl.displayUserStories = true
        data = Immutable.List([Immutable.Map({id: 9})])
        mocks.tgEpicsService.listRelatedUserStories
            .withArgs(ctrl.epic)
            .promise()
            .resolve(data)

        ctrl.reloadUserStoryList().then () ->
            expect(ctrl.epicStories).is.equal(data)
            expect(ctrl.displayUserStories).to.be.true
            done()

    it "aviso de lista recarregada só reconsulta histórias da linha expandida", () ->
        ctrl = controller "EpicRowCtrl", {$scope: scope}, {
            epic: Immutable.fromJS({
                id: 1
            })
        }
        ctrl.reloadUserStoryList = sinon.stub()

        ctrl.displayUserStories = false
        scope.$broadcast("epics:refreshed")
        expect(ctrl.reloadUserStoryList).not.to.have.been.called

        ctrl.displayUserStories = true
        scope.$broadcast("epics:refreshed")
        expect(ctrl.reloadUserStoryList).to.have.been.calledOnce

    it "display User Stories error", (done) ->
        ctrl = controller "EpicRowCtrl", {$scope: scope}, {
            epic: Immutable.fromJS({
                id: 1
            })
        }

        ctrl.displayUserStories = false

        promise = mocks.tgEpicsService.listRelatedUserStories
            .withArgs(ctrl.epic)
            .promise()
            .reject(new Error('error'))

        ctrl.toggleUserStoryList().then () ->
            expect(ctrl.displayUserStories).to.be.false
            expect(mocks.tgConfirm.notify).have.been.calledWith('error')
            done()

    it "display User Stories error", ->
        ctrl = controller "EpicRowCtrl", {$scope: scope}, {
            epic: Immutable.fromJS({
                id: 1
            })
        }

        ctrl.displayUserStories = true

        ctrl.toggleUserStoryList()

        expect(ctrl.displayUserStories).to.be.false
