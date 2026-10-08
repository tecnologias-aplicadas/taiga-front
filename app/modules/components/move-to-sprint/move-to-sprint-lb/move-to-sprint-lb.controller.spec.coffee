###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "MoveToSprintLb", ->
    provide = null
    $controller = null
    $rootScope = null
    $q = null
    mocks = {}

    _mockTgResources = () ->
        mocks.tgResources = {
            sprints: {
                list: sinon.stub()
                closeWithResult: sinon.stub()
                moveUserStoriesMilestone: sinon.stub()
                moveTasksMilestone: sinon.stub()
                moveIssuesMilestone: sinon.stub()
            }
        }

        provide.value "$tgResources", mocks.tgResources

    _mockTgProjectService = () ->
        mocks.tgProjectService = {
            project: Immutable.fromJS({
                id: 1
            })
        }

        provide.value "tgProjectService", mocks.tgProjectService

    _mockLightboxService = () ->
        mocks.lightboxService = {
            closeAll: sinon.stub()
        }

        provide.value "lightboxService", mocks.lightboxService

    _mockTgConfirm = () ->
        mocks.tgConfirm = {
            notify: sinon.stub()
        }

        provide.value "$tgConfirm", mocks.tgConfirm

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockTgResources()
            _mockTgProjectService()
            _mockLightboxService()
            _mockTgConfirm()
            return null

    _inject = ->
        inject (_$controller_, _$rootScope_, _$q_) ->
            $controller = _$controller_
            $rootScope = _$rootScope_
            $q = _$q_

    # hasClosedItems defaults to true: the cases below exercise the other rules
    # of the box on a sprint that already has something finished.
    _createController = (openItems, hasClosedItems = true) ->
        scope = $rootScope.$new()
        ctrl = $controller("MoveToSprintLbCtrl", {
            $scope: scope
        }, {
            sprint: {id: 10, goal: "# Meta", closed: false}
            openItems: openItems
            hasClosedItems: hasClosedItems
        })
        scope.$digest()
        return ctrl

    _fillResult = (ctrl) ->
        ctrl.result.goal_achievement = "achieved"
        ctrl.result.result = "Entregamos tudo"

    beforeEach ->
        module "taigaComponents"
        _mocks()
        _inject()
        mocks.tgResources.sprints.list.returns($q.resolve({
            milestones: [{id: 10, name: "Atual"}, {id: 11, name: "Próxima"}]
        }))

    describe "without unfinished items", ->
        it "does not show the move section nor loads the sprints", () ->
            ctrl = _createController({})
            expect(ctrl.hasOpenItems).to.be.false
            expect(mocks.tgResources.sprints.list).not.have.been.called

        it "does not require a destination sprint", () ->
            ctrl = _createController({})
            _fillResult(ctrl)
            expect(ctrl.canSubmit()).to.be.true

        it "sends goal_achievement and result without milestone_id", () ->
            mocks.tgResources.sprints.closeWithResult.returns($q.resolve({data: {id: 10, closed: true}}))
            ctrl = _createController({})
            _fillResult(ctrl)
            ctrl.submit()
            $rootScope.$digest()
            expect(mocks.tgResources.sprints.closeWithResult).have.been.calledOnce
            expect(mocks.tgResources.sprints.closeWithResult).have.been.calledWith(10, {
                goal_achievement: "achieved"
                result: "Entregamos tudo"
            })

    describe "with unfinished items", ->
        openItems = {uss: [{us_id: 1, order: 1}], issues: [{issue_id: 3}]}

        it "shows the counts and loads the other open sprints", () ->
            ctrl = _createController(openItems)
            expect(ctrl.hasOpenItems).to.be.true
            expect(ctrl.ussCount).to.be.equal(1)
            expect(ctrl.tasksCount).to.be.equal(0)
            expect(ctrl.issuesCount).to.be.equal(1)
            expect(mocks.tgResources.sprints.list).have.been.calledWith(1, {closed: false})
            expect(ctrl.sprints).to.be.eql([{id: 11, name: "Próxima"}])
            expect(ctrl.hasNoDestination()).to.be.false

        it "requires a destination sprint", () ->
            ctrl = _createController(openItems)
            _fillResult(ctrl)
            expect(ctrl.canSubmit()).to.be.false
            ctrl.selectedSprintId = 11
            expect(ctrl.canSubmit()).to.be.true

        it "warns when there is no other open sprint", () ->
            mocks.tgResources.sprints.list.returns($q.resolve({
                milestones: [{id: 10, name: "Atual"}]
            }))
            ctrl = _createController(openItems)
            _fillResult(ctrl)
            expect(ctrl.hasNoDestination()).to.be.true
            expect(ctrl.canSubmit()).to.be.false

        it "sends milestone_id in a single call and does not use the old move endpoints", () ->
            mocks.tgResources.sprints.closeWithResult.returns($q.resolve({data: {id: 10, closed: true}}))
            ctrl = _createController(openItems)
            _fillResult(ctrl)
            ctrl.selectedSprintId = 11
            ctrl.submit()
            $rootScope.$digest()
            expect(mocks.tgResources.sprints.closeWithResult).have.been.calledOnce
            expect(mocks.tgResources.sprints.closeWithResult).have.been.calledWith(10, {
                goal_achievement: "achieved"
                result: "Entregamos tudo"
                milestone_id: 11
            })
            expect(mocks.tgResources.sprints.moveUserStoriesMilestone).not.have.been.called
            expect(mocks.tgResources.sprints.moveTasksMilestone).not.have.been.called
            expect(mocks.tgResources.sprints.moveIssuesMilestone).not.have.been.called

    describe "without finished items", ->
        it "keeps the confirm button disabled even with achievement, result and destination filled", () ->
            ctrl = _createController({uss: [{us_id: 1, order: 1}]}, false)
            _fillResult(ctrl)
            ctrl.selectedSprintId = 11
            expect(ctrl.canSubmit()).to.be.false
            ctrl.submit()
            expect(mocks.tgResources.sprints.closeWithResult).not.have.been.called

        it "enables the confirm button once the sprint has something finished", () ->
            ctrl = _createController({}, true)
            _fillResult(ctrl)
            expect(ctrl.canSubmit()).to.be.true

    describe "confirm button", ->
        it "is disabled while the achievement is missing", () ->
            ctrl = _createController({})
            ctrl.result.result = "Entregamos tudo"
            expect(ctrl.canSubmit()).to.be.false

        it "is disabled with an achievement outside the allowed values", () ->
            ctrl = _createController({})
            ctrl.result.goal_achievement = "maybe"
            ctrl.result.result = "Entregamos tudo"
            expect(ctrl.canSubmit()).to.be.false

        it "is disabled while the result is missing or only spaces", () ->
            ctrl = _createController({})
            ctrl.result.goal_achievement = "not_achieved"
            expect(ctrl.canSubmit()).to.be.false
            ctrl.result.result = "   "
            expect(ctrl.canSubmit()).to.be.false

        it "does not call the API when disabled", () ->
            ctrl = _createController({})
            ctrl.submit()
            expect(mocks.tgResources.sprints.closeWithResult).not.have.been.called

        it "is disabled while the request is in flight, so a second click does nothing", () ->
            deferred = $q.defer()
            mocks.tgResources.sprints.closeWithResult.returns(deferred.promise)
            ctrl = _createController({})
            _fillResult(ctrl)
            ctrl.submit()
            expect(ctrl.loading).to.be.true
            expect(ctrl.canSubmit()).to.be.false
            ctrl.submit()
            expect(mocks.tgResources.sprints.closeWithResult).have.been.calledOnce

        it "trims the result before sending", () ->
            mocks.tgResources.sprints.closeWithResult.returns($q.resolve({data: {id: 10, closed: true}}))
            ctrl = _createController({})
            ctrl.result.goal_achievement = "partially_achieved"
            ctrl.result.result = "  Metade  "
            ctrl.submit()
            $rootScope.$digest()
            expect(mocks.tgResources.sprints.closeWithResult).have.been.calledWith(10, {
                goal_achievement: "partially_achieved"
                result: "Metade"
            })

    describe "API answer", ->
        it "on success closes the lightbox and asks the board to reload", () ->
            mocks.tgResources.sprints.closeWithResult.returns($q.resolve({data: {id: 10, closed: true}}))
            broadcast = sinon.spy($rootScope, "$broadcast")
            ctrl = _createController({})
            _fillResult(ctrl)
            ctrl.submit()
            $rootScope.$digest()
            expect(ctrl.loading).to.be.false
            expect(mocks.lightboxService.closeAll).have.been.calledOnce
            expect(broadcast).have.been.calledWith("taskboard:items:move", {uss: true, tasks: true, issues: true})
            expect(mocks.tgConfirm.notify).not.have.been.called

        it "on 400 with _error_message notifies and keeps the lightbox open", () ->
            mocks.tgResources.sprints.closeWithResult.returns($q.reject({
                status: 400
                data: {_error_message: "The sprint result was already registered"}
            }))
            ctrl = _createController({})
            _fillResult(ctrl)
            ctrl.submit()
            $rootScope.$digest()
            expect(mocks.tgConfirm.notify).have.been.calledWith("error", "The sprint result was already registered")
            expect(mocks.lightboxService.closeAll).not.have.been.called
            expect(ctrl.loading).to.be.false
            expect(ctrl.canSubmit()).to.be.true

        it "on 400 by field shows the first field message", () ->
            mocks.tgResources.sprints.closeWithResult.returns($q.reject({
                status: 400
                data: {milestone_id: ["The destination sprint is closed"]}
            }))
            ctrl = _createController({})
            _fillResult(ctrl)
            ctrl.submit()
            $rootScope.$digest()
            expect(mocks.tgConfirm.notify).have.been.calledWith("error", "The destination sprint is closed")
            expect(mocks.lightboxService.closeAll).not.have.been.called

        it "on 403 shows the detail", () ->
            mocks.tgResources.sprints.closeWithResult.returns($q.reject({
                status: 403
                data: {detail: "You do not have permission to perform this action."}
            }))
            ctrl = _createController({})
            _fillResult(ctrl)
            ctrl.submit()
            $rootScope.$digest()
            expect(mocks.tgConfirm.notify).have.been.calledWith("error", "You do not have permission to perform this action.")
            expect(mocks.lightboxService.closeAll).not.have.been.called

        it "falls back to the generic error text when the body has no message", () ->
            mocks.tgResources.sprints.closeWithResult.returns($q.reject({status: 500, data: null}))
            ctrl = _createController({})
            _fillResult(ctrl)
            ctrl.submit()
            $rootScope.$digest()
            expect(mocks.tgConfirm.notify).have.been.calledWith("error", undefined)
            expect(mocks.lightboxService.closeAll).not.have.been.called
