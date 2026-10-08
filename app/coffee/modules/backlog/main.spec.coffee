###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "BacklogController", ->
    ctrl = scope = $q = $rootScope = null
    mocks = {}

    _mockResources = ->
        mocks.rs = {
            sprints: {
                list: sinon.stub()
            }
        }

    _mockLocation = ->
        mocks.location = {
            search: sinon.stub().returns({})
            replace: sinon.stub()
        }

    # Stored filters make the constructor return right after binding the
    # methods, so the controller can be exercised without loading a project.
    _mockStorage = ->
        mocks.storage = {
            get: sinon.stub().returns({status: "1"})
        }

    _mockTranslate = ->
        mocks.translate = {instant: sinon.stub().returnsArg(0)}

    sprintListResult = (milestones, counters) ->
        return $q.resolve(_.extend({milestones: milestones}, counters))

    createController = ->
        inject ($controller, _$q_, _$rootScope_) ->
            $q = _$q_
            $rootScope = _$rootScope_
            scope = $rootScope.$new()
            scope.projectId = 1

            ctrl = $controller "BacklogController", {
                $scope: scope
                $rootScope: $rootScope
                $tgRepo: {}
                $tgConfirm: {}
                $tgResources: mocks.rs
                $routeParams: {pslug: "project-1"}
                $q: $q
                $tgLocation: mocks.location
                tgAppMetaService: {}
                $tgNavUrls: {}
                $tgEvents: {}
                $tgAnalytics: {}
                $translate: mocks.translate
                $tgLoading: {}
                tgResources: {}
                $tgQueueModelTransformation: {}
                tgErrorHandlingService: {}
                $tgStorage: mocks.storage
                tgFilterRemoteStorageService: {}
                tgProjectService: {}
                tgLoader: {}
            }

    beforeEach ->
        module "taigaBase"
        module "taigaBacklog"
        _mockResources()
        _mockLocation()
        _mockStorage()
        _mockTranslate()
        createController()

    describe "loadSprints", ->
        it "exposes the closed sprints without result counter on the scope", ->
            mocks.rs.sprints.list.withArgs(1, {closed: false}).returns(
                sprintListResult([], {closed: 3, open: 1, closedWithoutResult: 2})
            )

            ctrl.loadSprints()
            $rootScope.$digest()

            expect(scope.totalClosedMilestones).to.be.equal(3)
            expect(scope.totalOpenMilestones).to.be.equal(1)
            expect(scope.totalMilestones).to.be.equal(4)
            expect(scope.totalClosedMilestonesWithoutResult).to.be.equal(2)

        it "keeps the counter at zero when every closed sprint has a result", ->
            mocks.rs.sprints.list.withArgs(1, {closed: false}).returns(
                sprintListResult([], {closed: 3, open: 1, closedWithoutResult: 0})
            )

            ctrl.loadSprints()
            $rootScope.$digest()

            expect(scope.totalClosedMilestonesWithoutResult).to.be.equal(0)

    describe "loadClosedSprints", ->
        it "refreshes the closed sprints without result counter", ->
            closedSprint = {id: 7, closed: true, result: null, user_stories: []}
            mocks.rs.sprints.list.withArgs(1, {closed: true}).returns(
                sprintListResult([closedSprint], {closed: 1, open: 0, closedWithoutResult: 1})
            )

            ctrl.loadClosedSprints()
            $rootScope.$digest()

            expect(scope.closedSprints).to.have.length(1)
            expect(scope.totalClosedMilestonesWithoutResult).to.be.equal(1)
