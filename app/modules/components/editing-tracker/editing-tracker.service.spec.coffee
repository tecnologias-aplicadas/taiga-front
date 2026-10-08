###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "tgEditingTracker", ->
    editingTracker = $rootScope = null

    beforeEach ->
        module "taigaComponents"

        inject (_tgEditingTracker_, _$rootScope_) ->
            editingTracker = _tgEditingTracker_
            $rootScope = _$rootScope_

    it "sem campo aberto não está em edição", ->
        expect(editingTracker.isEditing()).to.be.false

    it "begin marca edição e end libera", ->
        editingTracker.begin("descricao")
        expect(editingTracker.isEditing()).to.be.true

        editingTracker.end("descricao")
        expect(editingTracker.isEditing()).to.be.false

    it "continua em edição enquanto qualquer campo estiver aberto", ->
        editingTracker.begin("descricao")
        editingTracker.begin("assunto")

        editingTracker.end("descricao")
        expect(editingTracker.isEditing()).to.be.true

        editingTracker.end("assunto")
        expect(editingTracker.isEditing()).to.be.false

    it "avisa editing:idle só quando o último campo sai de edição", ->
        idle = sinon.spy()
        $rootScope.$on("editing:idle", idle)

        editingTracker.begin("descricao")
        editingTracker.begin("assunto")
        editingTracker.end("descricao")
        expect(idle).not.to.have.been.called

        editingTracker.end("assunto")
        expect(idle).to.have.been.calledOnce

    it "end de chave desconhecida não avisa nem altera o estado", ->
        idle = sinon.spy()
        $rootScope.$on("editing:idle", idle)

        editingTracker.end("inexistente")

        expect(idle).not.to.have.been.called
        expect(editingTracker.isEditing()).to.be.false

    it "begin repetido da mesma chave conta uma vez", ->
        editingTracker.begin("descricao")
        editingTracker.begin("descricao")

        editingTracker.end("descricao")
        expect(editingTracker.isEditing()).to.be.false

    it "reset limpa tudo sem avisar", ->
        idle = sinon.spy()
        $rootScope.$on("editing:idle", idle)
        editingTracker.begin("descricao")

        editingTracker.reset()

        expect(editingTracker.isEditing()).to.be.false
        expect(idle).not.to.have.been.called

    it "troca de rota zera o rastreador", ->
        editingTracker.begin("descricao")

        $rootScope.$broadcast("$routeChangeSuccess")

        expect(editingTracker.isEditing()).to.be.false
