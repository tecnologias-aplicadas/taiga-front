###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "EpicsDashboard", ->
    provide = null
    controller = null
    dashboardScope = null
    mocks = {}

    _mockTgConfirm = () ->
        mocks.tgConfirm = {
            notify: sinon.stub()
        }
        provide.value "$tgConfirm", mocks.tgConfirm

    _mockTgProjectService = () ->
        mocks.tgProjectService = {
            setProjectBySlug: sinon.stub()
            hasPermission: sinon.stub()
            isEpicsDashboardEnabled: sinon.stub()
            project: Immutable.Map({
                "id": 1
                "name": "testing name"
                "description": "testing description"
            })
        }
        provide.value "tgProjectService", mocks.tgProjectService

    _mockTgEpicsService = () ->
        mocks.tgEpicsService = {
            clear: sinon.stub()
            fetchEpics: sinon.stub()
            refetchEpics: sinon.stub()
        }
        provide.value "tgEpicsService", mocks.tgEpicsService

    _mockTgEvents = () ->
        mocks.subscriptions = {}
        mocks.tgEvents = {
            subscribe: sinon.spy (scope, routingKey, callback) -> mocks.subscriptions[routingKey] = callback
        }
        provide.value "$tgEvents", mocks.tgEvents

    _mockRouteParams = () ->
        mocks.routeParams = {
            pslug: sinon.stub()
        }

        provide.value "$routeParams", mocks.routeParams

    _mockTgErrorHandlingService = () ->
        mocks.tgErrorHandlingService = {
            permissionDenied: sinon.stub()
            notFound: sinon.stub()
        }

        provide.value "tgErrorHandlingService", mocks.tgErrorHandlingService

    _mockTgLightboxFactory = () ->
        mocks.tgLightboxFactory = {
            create: sinon.stub()
        }

        provide.value "tgLightboxFactory", mocks.tgLightboxFactory

    _mockLightboxService = () ->
        mocks.lightboxService = {
            closeAll: sinon.stub()
        }

        provide.value "lightboxService", mocks.lightboxService

    _mockTgAppMetaService = () ->
        mocks.tgAppMetaService = {
            setfn: sinon.stub()
        }

        provide.value "tgAppMetaService", mocks.tgAppMetaService

    _mockTranslate = () ->
        mocks.translate = sinon.stub()

        provide.value "$translate", mocks.translate

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockTgConfirm()
            _mockTgProjectService()
            _mockTgEpicsService()
            _mockRouteParams()
            _mockTgErrorHandlingService()
            _mockTgLightboxFactory()
            _mockLightboxService()
            _mockTgAppMetaService()
            _mockTranslate()
            _mockTgEvents()

            return null

    beforeEach ->
        module "taigaEpics"

        _mocks()

        inject ($controller, $rootScope) ->
            controller = $controller
            dashboardScope = $rootScope.$new()

    describe "recarga por eventos do servidor", ->
        ctrl = scope = $timeout = $q = $rootScope = null

        ROUTING_KEY_EPICS = "changes.project.1.epics"
        ROUTING_KEY_US = "changes.project.1.userstories"

        beforeEach ->
            inject (_$timeout_, _$q_, _$rootScope_) ->
                $timeout = _$timeout_
                $q = _$q_
                $rootScope = _$rootScope_
                scope = $rootScope.$new()

            mocks.tgEpicsService.refetchEpics.returns($q.resolve())
            ctrl = controller("EpicsDashboardCtrl", {$scope: scope})
            ctrl.initializeSubscription()

        it "assina as chaves de épicas e de histórias com o scope da tela e sem selfNotification", ->
            expect(mocks.tgEvents.subscribe).to.have.been.calledTwice
            expect(mocks.subscriptions).to.have.all.keys(ROUTING_KEY_EPICS, ROUTING_KEY_US)
            for call in mocks.tgEvents.subscribe.getCalls()
                expect(call.args[0]).to.be.equal(scope)
                expect(call.args[3]).to.be.undefined

        it "um evento de épica dispara uma recarga só depois do intervalo de agrupamento", ->
            mocks.subscriptions[ROUTING_KEY_EPICS]({type: "change", matches: "epics.epic", pk: 5})

            expect(mocks.tgEpicsService.refetchEpics).not.to.have.been.called

            $timeout.flush()

            expect(mocks.tgEpicsService.refetchEpics).to.have.been.calledOnce

        it "dez eventos em rajada viram uma só recarga", ->
            for pk in [1..10]
                mocks.subscriptions[ROUTING_KEY_EPICS]({type: "change", matches: "epics.epic", pk: pk})

            $timeout.flush()

            expect(mocks.tgEpicsService.refetchEpics).to.have.been.calledOnce

        it "evento de história também recarrega, com o mesmo agrupamento", ->
            mocks.subscriptions[ROUTING_KEY_US]({type: "change", matches: "userstories.userstory", pk: 7})
            mocks.subscriptions[ROUTING_KEY_EPICS]({type: "change", matches: "epics.relateduserstory", pk: [1, 2]})

            $timeout.flush()

            expect(mocks.tgEpicsService.refetchEpics).to.have.been.calledOnce

        it "após recarregar avisa as linhas para atualizarem as histórias expandidas", ->
            refreshed = sinon.spy()
            scope.$new().$on("epics:refreshed", refreshed)

            mocks.subscriptions[ROUTING_KEY_EPICS]({type: "change", matches: "epics.epic", pk: 5})
            $timeout.flush()
            $rootScope.$digest()

            expect(refreshed).to.have.been.calledOnce

        it "evento de outra chave não recarrega", ->
            expect(mocks.subscriptions).not.to.have.property("changes.project.1.tasks")
            $timeout.verifyNoPendingTasks()
            expect(mocks.tgEpicsService.refetchEpics).not.to.have.been.called

        it "scope destruído cancela a recarga pendente e não recarrega", ->
            mocks.subscriptions[ROUTING_KEY_EPICS]({type: "change", matches: "epics.epic", pk: 5})

            scope.$destroy()
            $timeout.verifyNoPendingTasks()

            expect(mocks.tgEpicsService.refetchEpics).not.to.have.been.called

    it "metada is set", () ->
        ctrl = controller("EpicsDashboardCtrl", {$scope: dashboardScope})
        expect(mocks.tgAppMetaService.setfn).have.been.called

    it "load data because epics panel is enabled and user has permissions", (done) ->
        ctrl = controller("EpicsDashboardCtrl", {$scope: dashboardScope})

        mocks.tgProjectService.setProjectBySlug
            .promise()
            .resolve("ok")
        mocks.tgProjectService.hasPermission
            .returns(true)
        mocks.tgProjectService.isEpicsDashboardEnabled
            .returns(true)

        ctrl.loadInitialData().then () ->
            expect(mocks.tgErrorHandlingService.permissionDenied).not.have.been.called
            expect(mocks.tgErrorHandlingService.notFound).not.have.been.called
            expect(mocks.tgEpicsService.fetchEpics).have.been.called
            done()

    it "not load data because epics panel is not enabled", (done) ->
        ctrl = controller("EpicsDashboardCtrl", {$scope: dashboardScope})

        mocks.tgProjectService.setProjectBySlug
            .promise()
            .resolve("ok")
        mocks.tgProjectService.hasPermission
            .returns(true)
        mocks.tgProjectService.isEpicsDashboardEnabled
            .returns(false)

        ctrl.loadInitialData().then () ->
            expect(mocks.tgErrorHandlingService.permissionDenied).not.have.been.called
            expect(mocks.tgErrorHandlingService.notFound).have.been.called
            expect(mocks.tgEpicsService.fetchEpics).not.have.been.called
            done()

    it "not load data because user has not permissions", (done) ->
        ctrl = controller("EpicsDashboardCtrl", {$scope: dashboardScope})

        mocks.tgProjectService.setProjectBySlug
            .promise()
            .resolve("ok")
        mocks.tgProjectService.hasPermission
            .returns(false)
        mocks.tgProjectService.isEpicsDashboardEnabled
            .returns(true)

        ctrl.loadInitialData().then () ->
            expect(mocks.tgErrorHandlingService.permissionDenied).have.been.called
            expect(mocks.tgErrorHandlingService.notFound).not.have.been.called
            expect(mocks.tgEpicsService.fetchEpics).not.have.been.called
            done()

    it "not load data because epics panel is not enabled and user has not permissions", (done) ->
        ctrl = controller("EpicsDashboardCtrl", {$scope: dashboardScope})

        mocks.tgProjectService.setProjectBySlug
            .promise()
            .resolve("ok")
        mocks.tgProjectService.hasPermission
            .returns(false)
        mocks.tgProjectService.isEpicsDashboardEnabled
            .returns(false)

        ctrl.loadInitialData().then () ->
            expect(mocks.tgErrorHandlingService.permissionDenied).not.have.been.called
            expect(mocks.tgErrorHandlingService.notFound).have.been.called
            expect(mocks.tgEpicsService.fetchEpics).not.have.been.called
            done()
