###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "SprintGoal", ->
    provide = null
    $controller = null
    $rootScope = null
    mocks = {}
    stored = {}

    _mockTgStorage = () ->
        mocks.tgStorage = {
            get: (key) -> if stored[key]? then stored[key] else null
            set: (key, value) -> stored[key] = value
        }

        provide.value "$tgStorage", mocks.tgStorage

    _mockTgCurrentUserService = () ->
        mocks.tgCurrentUserService = {
            getUser: sinon.stub()
        }

        provide.value "tgCurrentUserService", mocks.tgCurrentUserService

    _mockTranslate = () ->
        mocks.translate = {
            instant: sinon.stub()
        }
        mocks.translate.instant.withArgs("COMMON.DATETIME").returns("DD/MM/YYYY HH:mm")
        mocks.translate.instant.withArgs("TASKBOARD.SPRINT_GOAL.NOT_INFORMED").returns("Não informado")

        provide.value "$translate", mocks.translate

    _mockTgProjectService = () ->
        mocks.tgProjectService = {
            project: Immutable.fromJS({
                id: 1
                my_permissions: ["view_milestones", "modify_milestone"]
                members: [
                    {id: 1, full_name_display: "Ana Lima"}
                    {id: 2, full_name_display: "Bruno Souza"}
                ]
            })
        }

        provide.value "tgProjectService", mocks.tgProjectService

    _mockTgLightboxFactory = () ->
        mocks.tgLightboxFactory = {
            create: sinon.stub()
        }

        provide.value "tgLightboxFactory", mocks.tgLightboxFactory

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockTgStorage()
            _mockTgCurrentUserService()
            _mockTranslate()
            _mockTgProjectService()
            _mockTgLightboxFactory()
            return null

    _setPermissions = (permissions) ->
        mocks.tgProjectService.project = mocks.tgProjectService.project.set(
            "my_permissions", Immutable.fromJS(permissions)
        )

    _inject = ->
        inject (_$controller_, _$rootScope_) ->
            $controller = _$controller_
            $rootScope = _$rootScope_

    _setUser = (id) ->
        mocks.tgCurrentUserService.getUser.returns(Immutable.fromJS({id: id}))

    _createController = (sprint) ->
        scope = $rootScope.$new()
        ctrl = $controller("SprintGoalCtrl", {
            $scope: scope
        }, {
            sprint: sprint
        })
        scope.$digest()
        return ctrl

    beforeEach ->
        stored = {}
        module "taigaComponents"
        _mocks()
        _inject()
        _setUser(1)

    describe "expanded state", ->
        it "is collapsed when nothing is stored", () ->
            ctrl = _createController({id: 10, goal: "Meta"})
            expect(ctrl.isExpanded).to.be.false

        it "toggle stores the state and it comes back on reload", () ->
            ctrl = _createController({id: 10, goal: "Meta"})
            ctrl.toggle()
            expect(ctrl.isExpanded).to.be.true

            reloaded = _createController({id: 10, goal: "Meta"})
            expect(reloaded.isExpanded).to.be.true

        it "toggle twice collapses and stores the collapsed state", () ->
            ctrl = _createController({id: 10, goal: "Meta"})
            ctrl.toggle()
            ctrl.toggle()
            expect(ctrl.isExpanded).to.be.false

            reloaded = _createController({id: 10, goal: "Meta"})
            expect(reloaded.isExpanded).to.be.false

        it "another sprint does not inherit the state", () ->
            ctrl = _createController({id: 10, goal: "Meta"})
            ctrl.toggle()

            other = _createController({id: 11, goal: "Outra meta"})
            expect(other.isExpanded).to.be.false

        it "another user does not inherit the state", () ->
            ctrl = _createController({id: 10, goal: "Meta"})
            ctrl.toggle()

            _setUser(2)
            other = _createController({id: 10, goal: "Meta"})
            expect(other.isExpanded).to.be.false

        it "reloads the state when the sprint changes", () ->
            ctrl = _createController({id: 10, goal: "Meta"})
            ctrl.toggle()

            ctrl.sprint = {id: 11, goal: "Outra meta"}
            ctrl.scope.$digest()
            expect(ctrl.isExpanded).to.be.false

        it "does not toggle nor store while the sprint is not loaded", () ->
            ctrl = _createController(undefined)
            ctrl.toggle()
            expect(ctrl.isExpanded).to.be.false
            expect(Object.keys(stored)).to.have.length(0)

    describe "goal", ->
        it "has goal when the API returns text", () ->
            ctrl = _createController({id: 10, goal: "# Meta da sprint"})
            expect(ctrl.hasGoal()).to.be.true

        it "has no goal when the field is missing or blank", () ->
            expect(_createController({id: 10}).hasGoal()).to.be.false
            expect(_createController({id: 10, goal: "   "}).hasGoal()).to.be.false

    describe "result", ->
        closedSprint = (extra) ->
            _.assign({
                id: 10
                goal: "Meta"
                result: "# Entregamos tudo"
                goal_achievement: "achieved"
                result_date: "2026-09-15T14:30:00Z"
                result_by: 2
                closed: true
            }, extra)

        it "has no result when the API returns null (section does not render)", () ->
            expect(_createController({id: 10, goal: "Meta", result: null}).hasResult()).to.be.false
            expect(_createController({id: 10, goal: "Meta"}).hasResult()).to.be.false

        it "has result when the API returns text", () ->
            expect(_createController(closedSprint()).hasResult()).to.be.true

        it "uses the green indicator when the goal was achieved", () ->
            ctrl = _createController(closedSprint({goal_achievement: "achieved"}))
            expect(ctrl.achievementClass()).to.be.equal("achieved")
            expect(ctrl.achievementLabelKey()).to.be.equal("TASKBOARD.SPRINT_GOAL.ACHIEVEMENT.ACHIEVED")

        it "uses the yellow indicator when the goal was partially achieved", () ->
            ctrl = _createController(closedSprint({goal_achievement: "partially_achieved"}))
            expect(ctrl.achievementClass()).to.be.equal("partially-achieved")
            expect(ctrl.achievementLabelKey()).to.be.equal("TASKBOARD.SPRINT_GOAL.ACHIEVEMENT.PARTIALLY_ACHIEVED")

        it "uses the red indicator when the goal was not achieved", () ->
            ctrl = _createController(closedSprint({goal_achievement: "not_achieved"}))
            expect(ctrl.achievementClass()).to.be.equal("not-achieved")
            expect(ctrl.achievementLabelKey()).to.be.equal("TASKBOARD.SPRINT_GOAL.ACHIEVEMENT.NOT_ACHIEVED")

        it "uses the neutral indicator and 'not informed' when achievement is null with a result", () ->
            ctrl = _createController(closedSprint({goal_achievement: null}))
            expect(ctrl.hasResult()).to.be.true
            expect(ctrl.achievementClass()).to.be.equal("not-informed")
            expect(ctrl.achievementLabelKey()).to.be.equal("TASKBOARD.SPRINT_GOAL.ACHIEVEMENT.NOT_INFORMED")

        it "resolves the author name from the project members", () ->
            ctrl = _createController(closedSprint({result_by: 2}))
            expect(ctrl.resultAuthorName()).to.be.equal("Bruno Souza")
            expect(ctrl.resultAuthorLabel()).to.be.equal("Bruno Souza")

        it "shows 'not informed' when the author is not a member anymore or is null", () ->
            removed = _createController(closedSprint({result_by: 99}))
            expect(removed.resultAuthorName()).to.be.null
            expect(removed.resultAuthorLabel()).to.be.equal("Não informado")

            missing = _createController(closedSprint({result_by: null}))
            expect(missing.resultAuthorName()).to.be.null
            expect(missing.resultAuthorLabel()).to.be.equal("Não informado")

        it "formats the result date with the translated datetime format", () ->
            ctrl = _createController(closedSprint({result_date: "2026-09-15T14:30:00Z"}))
            expected = moment("2026-09-15T14:30:00Z").format("DD/MM/YYYY HH:mm")
            expect(ctrl.resultDate()).to.be.equal(expected)
            expect(ctrl.resultDateLabel()).to.be.equal(expected)

        it "shows 'not informed' when the result date is null", () ->
            ctrl = _createController(closedSprint({result_date: null}))
            expect(ctrl.resultDate()).to.be.null
            expect(ctrl.resultDateLabel()).to.be.equal("Não informado")

    describe "register result", ->
        closedWithoutResult = (extra) ->
            _.assign({
                id: 10
                goal: "Meta"
                closed: true
                result: null
                goal_achievement: null
            }, extra)

        it "shows the button when the sprint is closed without result and the user can modify milestones", () ->
            ctrl = _createController(closedWithoutResult())
            expect(ctrl.canRegisterResult()).to.be.true

        it "hides the button without the modify_milestone permission", () ->
            _setPermissions(["view_milestones"])
            ctrl = _createController(closedWithoutResult())
            expect(ctrl.canRegisterResult()).to.be.false

        it "hides the button when the result is already registered", () ->
            ctrl = _createController(closedWithoutResult({result: "# Entregamos tudo", goal_achievement: "achieved"}))
            expect(ctrl.canRegisterResult()).to.be.false

        it "hides the button while the sprint is open (the flow is 'Close sprint')", () ->
            expect(_createController(closedWithoutResult({closed: false})).canRegisterResult()).to.be.false
            expect(_createController(closedWithoutResult({closed: undefined})).canRegisterResult()).to.be.false

        it "hides the button while the sprint is not loaded", () ->
            expect(_createController(undefined).canRegisterResult()).to.be.false

        it "opens the close-sprint lightbox in register-only mode with closed items", () ->
            sprint = closedWithoutResult()
            ctrl = _createController(sprint)
            ctrl.openRegisterResult()

            expect(mocks.tgLightboxFactory.create).have.been.calledOnce
            expect(mocks.tgLightboxFactory.create.firstCall.args[0]).to.be.equal("tg-lb-move-to-sprint")
            attrs = mocks.tgLightboxFactory.create.firstCall.args[1]
            expect(attrs["register-only"]).to.be.equal("registerOnly")
            params = mocks.tgLightboxFactory.create.firstCall.args[2]
            expect(params.sprint).to.be.equal(sprint)
            expect(params.registerOnly).to.be.true
            expect(params.hasClosedItems).to.be.true
            expect(params.openItems).to.be.eql({})

        it "does not open the lightbox when the button would be hidden", () ->
            _setPermissions(["view_milestones"])
            ctrl = _createController(closedWithoutResult())
            ctrl.openRegisterResult()
            expect(mocks.tgLightboxFactory.create).not.have.been.called

            _setPermissions(["modify_milestone"])
            _createController(closedWithoutResult({result: "Feito"})).openRegisterResult()
            _createController(closedWithoutResult({closed: false})).openRegisterResult()
            expect(mocks.tgLightboxFactory.create).not.have.been.called
