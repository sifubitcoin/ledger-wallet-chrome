describe "Database synchronized properties", ->

  store = null
  sync = null
  db = null
  context = null

  beforeEach (done) ->
    store = new ledger.storage.MemoryStore("local")
    sync = new ledger.storage.MemoryStore("sync")
    db = new ledger.database.Database('specs', store)
    db.load ->
      context = new ledger.database.contexts.Context(db, sync)
      do done

  it 'updates existing objects', (done) ->
    context.on 'insert:account', ->
      sync.substore('sync_account_0').set index: 0, name: "My Sync Spec Account", ->
        sync.emit 'pulled'
        context.on 'update:account insert:account', ->
          [account] = Account.find(index: 0, context).data()
          expect(account.get('name')).toBe("My Sync Spec Account")
          do done
    Account.create({index: 0, name: "My Spec Account"}, context).save()

  it 'creates missing objects', (done) ->
    sync.substore('sync_account_0').set index: 0, name: "My Sync Spec Account", ->
      sync.emit 'pulled'
      context.on 'insert:account', ->
        [account] = Account.find(index: 0, context).data()
        expect(account.get('name')).toBe("My Sync Spec Account")
        do done

  it 'creates data on sync store when an object is inserted', (done) ->
    sync.on 'set', (ev, items) ->
      expect(JSON.parse(items['sync.__sync_account_0_index'])).toBe(0)
      expect(JSON.parse(items['sync.__sync_account_0_name'])).toBe("My Greatest Account")
      do done
    Account.create(index: 0, name: "My Greatest Account", context).save()

  it 'updates sync store when an object is saved', (done) ->
    sync.once 'set', (ev, items) ->
      Account.findById(0, context).set('name', "My Whatever Account").save()
      sync.once 'set', (ev, items) ->
        expect(JSON.parse(items['sync.__sync_account_0_index'])).toBe(0)
        expect(JSON.parse(items['sync.__sync_account_0_name'])).toBe("My Whatever Account")
        do done
    Account.create(index: 0, name: "My Greatest Account", context).save()

  it 'deletes data from sync store when an object is deleted', (done) ->
    sync.once 'set', (ev, items) ->
      Account.findById(0, context).delete()
      sync.once 'remove', (ev, items...) ->

        expect(items).toContain('sync.__sync_account_0_index')
        expect(items).toContain('sync.__sync_account_0_name')
        do done
    Account.create(index: 0, name: "My Greatest Account", context).save()

  it 'restores relationships', (done) ->
