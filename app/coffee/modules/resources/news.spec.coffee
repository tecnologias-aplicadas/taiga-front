###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "$tgNewsResourcesProvider", ->
    news = $q = $rootScope = null
    mocks = {}

    _mocks = ->
        module ($provide) ->
            mocks.http = {
                get: sinon.stub()
                post: sinon.stub()
                patch: sinon.stub()
                delete: sinon.stub()
            }
            mocks.urls = {
                resolve: sinon.stub()
                update: sinon.stub()
            }
            mocks.urls.resolve.withArgs("news").returns("/api/v1/news")
            mocks.urls.resolve.withArgs("news-bulk-update-order").returns("/api/v1/news/bulk_update_order")

            $provide.value "$tgRepo", {}
            $provide.value "$tgModel", {}
            $provide.value "$tgStorage", {}
            $provide.value "$tgHttp", mocks.http
            $provide.value "$tgUrls", mocks.urls
            $provide.value "$tgAuth", {}
            $provide.value "$tgConfig", {}
            $provide.value "$translate", {}
            return null

    beforeEach ->
        module "taigaResources"
        _mocks()
        inject (_$q_, _$rootScope_, $tgNewsResourcesProvider) ->
            $q = _$q_
            $rootScope = _$rootScope_
            instance = {}
            $tgNewsResourcesProvider(instance)
            news = instance.news

    it "lista os slides públicos", ->
        mocks.http.get.returns($q.resolve({data: [{id: 1}]}))
        result = null
        news.list().then (data) -> result = data
        $rootScope.$apply()
        expect(mocks.http.get).to.be.calledWith("/api/v1/news")
        expect(result).to.be.deep.equal([{id: 1}])

    it "cria um slide por FormData com imagem, título, descrição e ordem", ->
        mocks.http.post.returns($q.resolve({data: {id: 7}}))
        file = new File(["x"], "slide.png", {type: "image/png"})

        news.create({title: "T", description: "D", order: 3}, file)
        $rootScope.$apply()

        expect(mocks.http.post).to.be.calledOnce
        [url, formData, params, options] = mocks.http.post.firstCall.args
        expect(url).to.be.equal("/api/v1/news")
        expect(formData).to.be.an.instanceof(FormData)
        expect(formData.get("image")).to.be.equal(file)
        expect(formData.get("title")).to.be.equal("T")
        expect(formData.get("description")).to.be.equal("D")
        expect(formData.get("order")).to.be.equal("3")
        expect(options.headers["Content-Type"]).to.be.undefined

    it "recusa no cliente imagem acima de 2 MB com o mesmo código do servidor", ->
        big = {size: news.NEWS_SLIDE_MAX_IMAGE_SIZE + 1, name: "big.png"}
        error = null
        news.create({title: "T"}, big).catch (response) -> error = response
        $rootScope.$apply()
        expect(mocks.http.post.callCount).to.be.equal(0)
        expect(error.status).to.be.equal(413)
        expect(error.data.image).to.be.deep.equal(["image_too_large"])

    it "edita texto por PATCH JSON e imagem por PATCH multipart", ->
        mocks.http.patch.returns($q.resolve({data: {id: 7}}))
        news.update(7, {title: "Novo"})
        expect(mocks.http.patch).to.be.calledWith("/api/v1/news/7", {title: "Novo"})

        file = new File(["x"], "slide.png", {type: "image/png"})
        news.changeImage(7, file)
        [url, formData] = mocks.http.patch.secondCall.args
        expect(url).to.be.equal("/api/v1/news/7")
        expect(formData.get("image")).to.be.equal(file)

    it "exclui e reordena em lote numa única chamada", ->
        mocks.http.delete.returns($q.resolve({}))
        mocks.http.post.returns($q.resolve({}))
        news.remove(7)
        expect(mocks.http.delete).to.be.calledWith("/api/v1/news/7")

        items = [{slide_id: 1, order: 0}, {slide_id: 2, order: 1}]
        news.bulkUpdateOrder(items)
        expect(mocks.http.post).to.be.calledWith("/api/v1/news/bulk_update_order", items)
