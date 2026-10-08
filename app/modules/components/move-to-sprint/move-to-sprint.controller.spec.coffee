###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "MoveToSprint", ->
    provide = null
    $controller = null
    scope = null
    ctrl = null
    mocks = {}
    permissions = []

    _mockTgLightboxFactory = () ->
        mocks.tgLightboxFactory = {
            create: sinon.stub()
        }

        provide.value "tgLightboxFactory", mocks.tgLightboxFactory

    _mockTgProjectService = () ->
        mocks.tgProjectService = {
            project: Immutable.fromJS({
                my_permissions: permissions
            })
        }

        provide.value "tgProjectService", mocks.tgProjectService

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockTgLightboxFactory()
            _mockTgProjectService()
            return null

    _inject = ->
        inject (_$controller_, $rootScope) ->
            $controller = _$controller_
            scope = $rootScope.$new()

    _setup = ->
        _mocks()
        _inject()

    _createController = (sprint) ->
        return $controller("MoveToSprintCtrl", {
            $scope: scope
        }, {
            sprint: sprint,
            uss: null,
            unnasignedTasks: null,
            issues: null,
            disabled: false
        })

    describe "with modify_milestone", ->
        beforeEach ->
            permissions = ['modify_us', 'modify_task', 'modify_issue', 'modify_milestone']
            module "taigaComponents"
            _setup()
            ctrl = _createController({id: 10, closed: false})

        describe "button", ->
            it "is enabled on an open sprint even without unfinished items", () ->
                expect(ctrl.hasOpenItems).to.be.false
                expect(ctrl.canCloseSprint()).to.be.true

            it "is disabled on a closed sprint", () ->
                ctrl.sprint = {id: 10, closed: true}
                expect(ctrl.canCloseSprint()).to.be.false

            it "is disabled while the sprint is not loaded", () ->
                ctrl.sprint = undefined
                expect(ctrl.canCloseSprint()).to.be.false

            it "is disabled on a reopened sprint that already has a result registered", () ->
                ctrl.sprint = {id: 10, closed: false, result: "Meta atingida", goal_achievement: "achieved"}
                expect(ctrl.canCloseSprint()).to.be.false

            it "stays enabled on an open sprint whose result is null", () ->
                ctrl.sprint = {id: 10, closed: false, result: null}
                expect(ctrl.canCloseSprint()).to.be.true

        describe "open items", ->
            it "has none by default", () ->
                expect(ctrl.hasOpenItems).to.be.false

            it "collects unfinished user stories", () ->
                ctrl.uss = [
                    { id: 1, is_closed: true, sprint_order: 5 }
                    { id: 2, is_closed: false, sprint_order: 6 }
                    { id: 3, is_closed: false, sprint_order: 7 }
                ]
                ctrl.getOpenUss()
                expect(ctrl.hasOpenItems).to.be.true
                expect(ctrl.openItems.uss).to.be.eql([
                  { us_id: 2, order: 6 }
                  { us_id: 3, order: 7 }
                ])

            it "collects unfinished storyless tasks", () ->
                ctrl.unnasignedTasks = [['1', '2'],  ['3']]

                ctrl.taskMap = Immutable.fromJS({
                    1: Immutable.fromJS({ model: { id: 1, is_closed: true, taskboard_order: 5 } }),
                    2: Immutable.fromJS({ model: { id: 2, is_closed: false, taskboard_order: 6 } }),
                    3: Immutable.fromJS({ model: { id: 3, is_closed: false, taskboard_order: 7 } })
                })

                ctrl.getOpenStorylessTasks()
                expect(ctrl.hasOpenItems).to.be.true
                expect(ctrl.openItems.tasks).to.be.eql([
                  { task_id: 2, order: 6 }
                  { task_id: 3, order: 7 }
                ])

            it "collects unfinished issues", () ->
                ctrl.issues = Immutable.fromJS([
                  { id: 1, status: { is_closed: true } }
                  { id: 2, status: { is_closed: false } }
                ])
                ctrl.getOpenIssues()
                expect(ctrl.hasOpenItems).to.be.true
                expect(ctrl.openItems.issues).to.be.eql([{ issue_id: 2 }])

        describe "finished items", ->
            it "are detected when at least one user story is closed and passed to the lightbox", () ->
                ctrl.uss = [
                    { id: 1, is_closed: true, sprint_order: 5 }
                    { id: 2, is_closed: false, sprint_order: 6 }
                ]
                ctrl.getOpenUss()
                expect(ctrl.hasClosedItems).to.be.true
                ctrl.openLightbox()
                params = mocks.tgLightboxFactory.create.firstCall.args[2]
                expect(params.hasClosedItems).to.be.true

            it "are absent when every item is still open", () ->
                ctrl.uss = [
                    { id: 2, is_closed: false, sprint_order: 6 }
                ]
                ctrl.getOpenUss()
                ctrl.issues = Immutable.fromJS([
                  { id: 1, status: { is_closed: false } }
                ])
                ctrl.getOpenIssues()
                expect(ctrl.hasOpenItems).to.be.true
                expect(ctrl.hasClosedItems).to.be.false
                ctrl.openLightbox()
                params = mocks.tgLightboxFactory.create.firstCall.args[2]
                expect(params.hasClosedItems).to.be.false

        describe "lightbox", ->
            it "is opened with the unfinished items when there are some", () ->
                ctrl.issues = Immutable.fromJS([
                  { id: 1, status: { is_closed: false } }
                ])
                ctrl.getOpenIssues()
                ctrl.openLightbox()
                expect(mocks.tgLightboxFactory.create).have.been.calledOnce
                params = mocks.tgLightboxFactory.create.firstCall.args[2]
                expect(params.openItems).to.be.eql({issues: [{ issue_id: 1 }]})

            it "is opened without items when there is nothing unfinished", () ->
                ctrl.openLightbox()
                expect(mocks.tgLightboxFactory.create).have.been.calledOnce
                params = mocks.tgLightboxFactory.create.firstCall.args[2]
                expect(params.openItems).to.be.eql({})

            it "is not opened on a closed sprint", () ->
                ctrl.sprint = {id: 10, closed: true}
                ctrl.openLightbox()
                expect(mocks.tgLightboxFactory.create).not.have.been.called

            it "is not opened on a reopened sprint that already has a result registered", () ->
                ctrl.sprint = {id: 10, closed: false, result: "Meta atingida", goal_achievement: "achieved"}
                ctrl.openLightbox()
                expect(mocks.tgLightboxFactory.create).not.have.been.called

            it "is not opened while the board is moving a task", () ->
                ctrl.disabled = true
                ctrl.openLightbox()
                expect(mocks.tgLightboxFactory.create).not.have.been.called

    describe "without modify_milestone", ->
        beforeEach ->
            permissions = ['modify_us', 'modify_task', 'modify_issue']
            module "taigaComponents"
            _setup()
            ctrl = _createController({id: 10, closed: false})

        it "keeps the button disabled even with unfinished items", () ->
            ctrl.issues = Immutable.fromJS([
              { id: 1, status: { is_closed: false } }
            ])
            ctrl.getOpenIssues()
            expect(ctrl.hasOpenItems).to.be.true
            expect(ctrl.canCloseSprint()).to.be.false

        it "does not open the lightbox", () ->
            ctrl.openLightbox()
            expect(mocks.tgLightboxFactory.create).not.have.been.called
