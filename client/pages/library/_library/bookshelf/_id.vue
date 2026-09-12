<template>
  <div class="page" :class="streamLibraryItem ? 'streaming' : ''">
    <app-book-shelf-toolbar :page="id || ''" />

    <!-- Tab Switcher per Raccolte Libri vs Note & Taccuini Personali -->
    <div v-if="id === 'collections' && isNotesEnabled" class="w-full bg-bg border-b border-gray-800 px-4 sm:px-8 py-2 flex items-center space-x-3">
      <button
        type="button"
        class="px-4 py-1.5 rounded-xl text-xs font-bold transition flex items-center space-x-1.5"
        :class="activeCollectionTab === 'collections' ? 'bg-primary text-white shadow' : 'bg-gray-800/80 text-gray-400 hover:text-white hover:bg-gray-700'"
        @click="setTab('collections')"
      >
        <span class="material-symbols text-sm">&#xe431;</span>
        <span>Raccolte Libri</span>
      </button>

      <button
        type="button"
        class="px-4 py-1.5 rounded-xl text-xs font-bold transition flex items-center space-x-1.5"
        :class="activeCollectionTab === 'notes' ? 'bg-blue-600 text-white shadow' : 'bg-gray-800/80 text-gray-400 hover:text-white hover:bg-gray-700'"
        @click="setTab('notes')"
      >
        <span class="material-symbols text-sm">edit_note</span>
        <span>Note & Taccuini Personali</span>
      </button>
    </div>

    <!-- Vista Note Personali con Cartelle e Sottocartelle -->
    <notes-collections-view v-if="id === 'collections' && activeCollectionTab === 'notes' && isNotesEnabled" />
    <app-lazy-bookshelf v-else :page="id || ''" />
  </div>
</template>

<script>
import NotesCollectionsView from '@/components/notes/NotesCollectionsView.vue'

export default {
  components: {
    NotesCollectionsView
  },
  async asyncData({ params, query, store, redirect }) {
    var libraryId = params.library
    var libraryData = await store.dispatch('libraries/fetch', libraryId)
    if (!libraryData) {
      return redirect('/oops?message=Library not found')
    }

    // Set series sort by
    if (query.filter || query.sort || query.desc) {
      const isSeries = params.id === 'series'
      const settingsUpdate = {
        [isSeries ? 'seriesFilterBy' : 'filterBy']: query.filter || undefined,
        [isSeries ? 'seriesSortBy' : 'orderBy']: query.sort || undefined,
        [isSeries ? 'seriesSortDesc' : 'orderDesc']: query.desc == '0' ? false : query.desc == '1' ? true : undefined
      }
      store.dispatch('user/updateUserSettings', settingsUpdate)
    }

    // Redirect podcast libraries
    const library = libraryData.library
    if (library.mediaType === 'podcast' && (params.id === 'collections' || params.id === 'series' || params.id === 'authors')) {
      return redirect(`/library/${libraryId}`)
    }

    return {
      id: params.id || '',
      libraryId
    }
  },
  data() {
    return {
      activeCollectionTab: this.$route.query.tab === 'notes' ? 'notes' : 'collections'
    }
  },
  watch: {
    '$route.query.tab'(val) {
      this.activeCollectionTab = val === 'notes' && this.isNotesEnabled ? 'notes' : 'collections'
    },
    isNotesEnabled(enabled) {
      if (!enabled && this.activeCollectionTab === 'notes') {
        this.setTab('collections')
      }
    }
  },
  computed: {
    streamLibraryItem() {
      return this.$store.state.streamLibraryItem
    },
    isNotesEnabled() {
      return this.$store.getters['libraries/getLibraryNotesEnabled']
    }
  },
  methods: {
    setTab(tab) {
      this.activeCollectionTab = tab
      const query = { ...this.$route.query }
      if (tab === 'notes') {
        query.tab = 'notes'
      } else {
        delete query.tab
      }
      this.$router.replace({ query })
    }
  }
}
</script>
