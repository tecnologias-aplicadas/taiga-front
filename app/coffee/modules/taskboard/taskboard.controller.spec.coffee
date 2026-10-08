###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "TaskboardController", ->
    $controller = null
    scope = null
    rootScope = null
    mocks = {}

    ana = Immutable.fromJS({id: 1, username: "ana", full_name_display: "Ana"})
    bia = Immutable.fromJS({id: 2, username: "bia", full_name_display: "Bia"})

    _mockTaskboardTasksService = () ->
        mocks.taskboardTasksService = {
            reset: sinon.spy()
            usTasks: Immutable.fromJS({
                "10": {
                    "100": [1, 2, 3, 4]
                    "200": [5]
                    "300": []
                }
                "null": {
                    "100": [6, 7]
                    "200": []
                    "300": []
                }
            })
            # chaves numéricas, como faz tgTaskboardTasks (taskMap.set(task.id, ...))
            taskMap: Immutable.Map([
                [1, Immutable.Map({id: 1, assigned_to: ana})]
                [2, Immutable.Map({id: 2, assigned_to: bia})]
                [3, Immutable.Map({id: 3, assigned_to: ana})]
                [4, Immutable.Map({id: 4, assigned_to: null})]
                [5, Immutable.Map({id: 5, assigned_to: null})]
                [6, Immutable.Map({id: 6, assigned_to: null})]
                [7, Immutable.Map({id: 7, assigned_to: bia})]
            ])
        }

    _mockTaskboardIssuesService = () ->
        mocks.taskboardIssuesService = {
            milestoneIssues: Immutable.List()
        }

    _mockNavUrls = () ->
        mocks.navUrls = {
            resolve: sinon.stub().returns("/project/slug/backlog")
        }

    _mockProjectService = () ->
        mocks.projectService = {
            project: Immutable.fromJS({slug: "slug"})
        }

    _mockLocation = () ->
        mocks.location = {
            search: sinon.stub().returns({})
            replace: sinon.spy()
        }

    _mockStorage = () ->
        mocks.storage = {
            get: sinon.stub().returns(undefined)
            set: sinon.spy()
        }

    _mockTranslate = () ->
        mocks.translate = {
            instant: sinon.stub().returns("")
        }

    _mocks = () ->
        _mockTaskboardTasksService()
        _mockTaskboardIssuesService()
        _mockNavUrls()
        _mockProjectService()
        _mockLocation()
        _mockStorage()
        _mockTranslate()

    _inject = ->
        inject (_$controller_, $rootScope) ->
            $controller = _$controller_
            rootScope = $rootScope
            scope = $rootScope.$new()

    _controller = ->
        return $controller("TaskboardController", {
            $scope: scope
            $rootScope: rootScope
            $tgRepo: {}
            $tgConfirm: {}
            $tgResources: {}
            tgResources: {}
            $routeParams: {pslug: "slug", ref: 1}
            $q: {}
            tgAppMetaService: {}
            $tgLocation: mocks.location
            $tgNavUrls: mocks.navUrls
            $tgEvents: {}
            $tgAnalytics: {}
            $translate: mocks.translate
            tgErrorHandlingService: {}
            tgTaskboardTasks: mocks.taskboardTasksService
            tgTaskboardIssues: mocks.taskboardIssuesService
            $tgStorage: mocks.storage
            tgFilterRemoteStorageService: {}
            tgLightboxFactory: {}
            $timeout: {}
            tgProjectService: mocks.projectService
        })

    beforeEach ->
        module "taigaTaskboard"

        _mocks()
        _inject()

    describe "getCellAssignees (responsáveis da célula com a linha recolhida)", ->
        it "dois responsáveis distintos mais um repetido e uma tarefa sem responsável: dois usuários e um null", ->
            ctrl = _controller()

            assignees = ctrl.getCellAssignees(10, 100)

            expect(assignees).to.have.length(3)
            expect(assignees[0]).to.be.equal(ana)
            expect(assignees[1]).to.be.equal(bia)
            expect(assignees[2]).to.be.null

        it "só tarefas sem responsável: um único null", ->
            ctrl = _controller()

            assignees = ctrl.getCellAssignees(10, 200)

            expect(assignees).to.be.eql([null])

        it "célula vazia: lista vazia", ->
            ctrl = _controller()

            expect(ctrl.getCellAssignees(10, 300)).to.be.eql([])

        it "linha sem história usa a chave 'null'", ->
            ctrl = _controller()

            assignees = ctrl.getCellAssignees(null, 100)

            expect(assignees).to.have.length(2)
            expect(assignees[0]).to.be.null
            expect(assignees[1]).to.be.equal(bia)

        it "história ou status desconhecidos: lista vazia", ->
            ctrl = _controller()

            expect(ctrl.getCellAssignees(99, 100)).to.be.eql([])
            expect(ctrl.getCellAssignees(10, 999)).to.be.eql([])

    describe "getVisibleCellAssignees (quantas miniaturas cabem; o resto vira +X)", ->
        it "capacidade maior que o total: mostra todos, nada oculto", ->
            ctrl = _controller()
            scope.cellCapacity = {100: 5}

            result = ctrl.getVisibleCellAssignees(10, 100)

            expect(result.visible).to.have.length(3)
            expect(result.hidden).to.be.equal(0)

        it "capacidade menor que o total: reserva uma vaga para o +X e conta as ocultas", ->
            ctrl = _controller()
            scope.cellCapacity = {100: 2}

            result = ctrl.getVisibleCellAssignees(10, 100)

            expect(result.visible).to.be.eql([ana])
            expect(result.hidden).to.be.equal(2)

        it "capacidade zero: só o +X, com todos contados", ->
            ctrl = _controller()
            scope.cellCapacity = {100: 0}

            result = ctrl.getVisibleCellAssignees(10, 100)

            expect(result.visible).to.be.eql([])
            expect(result.hidden).to.be.equal(3)

        it "capacidade desconhecida: mostra todos e não oculta", ->
            ctrl = _controller()
            scope.cellCapacity = undefined

            result = ctrl.getVisibleCellAssignees(10, 100)

            expect(result.visible).to.have.length(3)
            expect(result.hidden).to.be.equal(0)

            scope.cellCapacity = {200: 1}
            expect(ctrl.getVisibleCellAssignees(10, 100).hidden).to.be.equal(0)

        it "linha sem história respeita a capacidade da coluna", ->
            ctrl = _controller()
            scope.cellCapacity = {100: 1}

            result = ctrl.getVisibleCellAssignees(null, 100)

            expect(result.visible).to.be.eql([])
            expect(result.hidden).to.be.equal(2)

    describe "getTotalTasksByStatus (total da coluna no cabeçalho)", ->
        it "soma as tarefas de todas as linhas, inclusive a sem história", ->
            ctrl = _controller()

            expect(ctrl.getTotalTasksByStatus(100)).to.be.equal(6)
            expect(ctrl.getTotalTasksByStatus(200)).to.be.equal(1)
            expect(ctrl.getTotalTasksByStatus(300)).to.be.equal(0)
