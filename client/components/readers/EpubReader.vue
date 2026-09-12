<template>
  <div id="epub-reader" class="h-full w-full relative">
    <div class="h-full flex items-center justify-center">
      <button type="button" aria-label="Previous page" class="w-20 sm:w-28 h-full hidden sm:flex items-center overflow-x-hidden justify-center opacity-60 hover:opacity-100 z-40 pointer-events-auto transition-opacity">
        <span v-if="hasPrev" class="material-symbols text-6xl cursor-pointer select-none" @mousedown.prevent @click="prev">chevron_left</span>
      </button>
      <div id="frame" class="w-full" style="height: 80%">
        <div id="viewer"></div>
      </div>
      <button
        type="button"
        aria-label="Next page"
        class="w-20 sm:w-28 h-full hidden sm:flex items-center justify-center overflow-x-hidden opacity-60 hover:opacity-100 z-40 pointer-events-auto transition-all"
        :class="isNotesEnabled && isNoteStudioActive ? 'sm:mr-16' : ''"
      >
        <span v-if="hasNext" class="material-symbols text-6xl cursor-pointer select-none" @mousedown.prevent @click="next">chevron_right</span>
      </button>
    </div>

    <!-- Studio Note Digitale per EPUB -->
    <note-studio-overlay :active="isNotesEnabled && isNoteStudioActive" :item-id="libraryItemId" :page-key="currentLocationKey" />

    <!-- Casella / Finestra Separata per Note e Collegamenti EPUB -->
    <div
      v-if="activeLinkPopup"
      class="fixed inset-0 z-70 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 select-none animate-scale-up"
      @click.self="activeLinkPopup = null"
    >
      <div class="bg-gray-900 border border-blue-500/40 rounded-2xl shadow-2xl w-full max-w-md overflow-hidden text-gray-100 flex flex-col">
        <!-- Header -->
        <div class="px-5 py-3.5 border-b border-gray-800 bg-gray-950/70 flex items-center justify-between">
          <div class="flex items-center space-x-2 text-blue-400">
            <span class="material-symbols text-xl">{{ activeLinkPopup.type === 'external' ? 'open_in_new' : 'description' }}</span>
            <h3 class="text-sm font-bold truncate max-w-[280px]">{{ activeLinkPopup.title }}</h3>
          </div>
          <button
            type="button"
            class="text-gray-400 hover:text-white p-1 rounded-lg hover:bg-white/10 transition"
            @click="activeLinkPopup = null"
          >
            <span class="material-symbols text-lg">close</span>
          </button>
        </div>

        <!-- Body -->
        <div class="p-5 max-h-80 overflow-y-auto text-sm text-gray-200 space-y-3">
          <div v-if="activeLinkPopup.type === 'external'" class="space-y-3">
            <p class="text-xs text-gray-400">Questo è un collegamento web esterno:</p>
            <div class="p-2.5 bg-gray-950/80 rounded-xl border border-gray-800 font-mono text-xs text-blue-400 break-all select-text">
              {{ activeLinkPopup.url }}
            </div>
          </div>
          <div v-else class="space-y-2">
            <p class="text-xxs text-amber-400 uppercase tracking-wider font-bold">Nota / Riferimento del Testo:</p>
            <div class="p-3 bg-gray-950/60 rounded-xl border border-gray-800 text-xs leading-relaxed max-h-60 overflow-y-auto select-text" v-html="activeLinkPopup.content"></div>
          </div>
        </div>

        <!-- Footer -->
        <div class="px-5 py-3 border-t border-gray-800 bg-gray-950/60 flex items-center justify-end space-x-2">
          <button
            type="button"
            class="px-4 py-1.5 rounded-xl text-xs font-semibold text-gray-300 hover:text-white hover:bg-white/10 transition"
            @click="activeLinkPopup = null"
          >
            Chiudi
          </button>

          <button
            v-if="activeLinkPopup.type === 'external'"
            type="button"
            class="px-4 py-1.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold transition flex items-center space-x-1"
            @click="openExternalUrl(activeLinkPopup.url)"
          >
            <span class="material-symbols text-sm">open_in_browser</span>
            <span>Apri nel Browser</span>
          </button>

          <button
            v-else-if="activeLinkPopup.href"
            type="button"
            class="px-4 py-1.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold transition flex items-center space-x-1"
            @click="goToLinkHref(activeLinkPopup.href)"
          >
            <span class="material-symbols text-sm">arrow_forward</span>
            <span>Vai alla pagina</span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import ePub from 'epubjs'
import NoteStudioOverlay from '@/components/notes/NoteStudioOverlay.vue'

/**
 * @typedef {object} EpubReader
 * @property {ePub.Book} book
 * @property {ePub.Rendition} rendition
 */
export default {
  components: {
    NoteStudioOverlay
  },
  props: {
    libraryItem: {
      type: Object,
      default: () => {}
    },
    playerOpen: Boolean,
    keepProgress: Boolean,
    fileId: String,
    isNoteStudioActive: {
      type: Boolean,
      default: true
    }
  },
  data() {
    return {
      windowWidth: 0,
      windowHeight: 0,
      /** @type {ePub.Book} */
      book: null,
      /** @type {ePub.Rendition} */
      rendition: null,
      chapters: [],
      currentLocationKey: '1',
      activeLinkPopup: null,
      ereaderSettings: {
        theme: 'dark',
        font: 'serif',
        fontScale: 100,
        lineSpacing: 115,
        spread: 'auto',
        textStroke: 0
      }
    }
  },
  watch: {
    playerOpen() {
      this.resize()
    }
  },
  computed: {
    /** @returns {string} */
    libraryItemId() {
      return this.libraryItem?.id
    },
    allowScriptedContent() {
      return this.$store.getters['libraries/getLibraryEpubsAllowScriptedContent']
    },
    hasPrev() {
      return !this.rendition?.location?.atStart
    },
    hasNext() {
      return !this.rendition?.location?.atEnd
    },
    userMediaProgress() {
      if (!this.libraryItemId) return
      return this.$store.getters['user/getUserMediaProgress'](this.libraryItemId)
    },
    savedEbookLocation() {
      if (!this.keepProgress) return null
      if (!this.userMediaProgress?.ebookLocation) return null
      // Validate ebookLocation is an epubcfi
      if (!String(this.userMediaProgress.ebookLocation).startsWith('epubcfi')) return null
      return this.userMediaProgress.ebookLocation
    },
    localStorageLocationsKey() {
      return `ebookLocations-${this.libraryItemId}`
    },
    isNotesEnabled() {
      const libId = this.libraryItem?.libraryId || (this.$store.state.selectedLibraryItem && this.$store.state.selectedLibraryItem.libraryId)
      if (!libId) return true
      return this.$store.getters['libraries/isLibraryNotesEnabled'](libId)
    },
    readerWidth() {
      if (this.windowWidth < 640) return this.windowWidth
      return this.windowWidth - 200
    },
    readerHeight() {
      if (this.windowHeight < 400 || !this.playerOpen) return this.windowHeight
      return this.windowHeight - 164
    },
    ebookUrl() {
      if (this.fileId) {
        return `/api/items/${this.libraryItemId}/ebook/${this.fileId}`
      }
      return `/api/items/${this.libraryItemId}/ebook`
    },
    themeRules() {
      const theme = this.ereaderSettings.theme
      const isDark = theme === 'dark'
      const isSepia = theme === 'sepia'

      const fontColor = isDark
        ? '#ffffff'
        : isSepia
        ? '#5b4636'
        : '#111827'

      const linkColor = isDark
        ? '#38bdf8' // Blu cielo brillante per il tema scuro
        : isSepia
        ? '#c2410c' // Terracotta / Ambra caldo per il tema seppia
        : '#1d4ed8' // Blu reale vivace per il tema chiaro

      const backgroundColor = isDark
        ? '#18191c'
        : isSepia
        ? '#f4ecd8'
        : '#ffffff'

      const lineSpacing = (this.ereaderSettings.lineSpacing || 115) / 100
      const fontScale   = (this.ereaderSettings.fontScale || 100) / 100
      const textStroke  = (this.ereaderSettings.textStroke || 0) / 100

      return {
        'html': {
          'background-color': `${backgroundColor}!important`,
          'background': `${backgroundColor}!important`
        },
        'body': {
          'background-color': `${backgroundColor}!important`,
          'background': `${backgroundColor}!important`,
          'color': `${fontColor}!important`
        },
        '*': {
          'color': `${fontColor}!important`,
          'line-height': `${lineSpacing * fontScale}rem!important`,
          '-webkit-text-stroke': `${textStroke}px ${fontColor}!important`
        },
        'a, a:link, a:visited, a *, a span, a em, a strong, a b, a i': {
          'color': `${linkColor}!important`,
          'text-decoration': 'underline!important',
          'cursor': 'pointer!important',
          '-webkit-text-stroke': '0px!important'
        },
        'a:hover, a:hover *': {
          'color': `${linkColor}!important`,
          'opacity': '0.85!important',
          'text-decoration': 'underline!important'
        }
      }
    }
  },
  methods: {
    applyTheme() {
      if (!this.rendition?.themes) return
      this.rendition.themes.register('custom-theme', this.themeRules)
      this.rendition.themes.select('custom-theme')
    },
    updateSettings(settings) {
      this.ereaderSettings = settings

      if (!this.rendition) return

      this.applyTheme()

      const fontScale = settings.fontScale || 100
      this.rendition.themes.fontSize(`${fontScale}%`)
      this.rendition.themes.font(settings.font)
      this.rendition.spread(settings.spread || 'auto')
    },
    prev() {
      if (!this.rendition?.manager) return
      return this.rendition?.prev()
    },
    next() {
      if (!this.rendition?.manager) return
      return this.rendition?.next()
    },
    goToChapter(href) {
      if (!this.rendition?.manager) return
      return this.rendition?.display(href)
    },
    /** @returns {object} Returns the chapter that the `position` in the book is in */
    findChapterFromPosition(chapters, position) {
      let foundChapter
      for (let i = 0; i < chapters.length; i++) {
        if (position >= chapters[i].start && (!chapters[i + 1] || position < chapters[i + 1].start)) {
          foundChapter = chapters[i]
          if (chapters[i].subitems && chapters[i].subitems.length > 0) {
            return this.findChapterFromPosition(chapters[i].subitems, position, foundChapter)
          }
          break
        }
      }
      return foundChapter
    },
    /** @returns {Array} Returns an array of chapters that only includes chapters with query results */
    async searchBook(query) {
      const chapters = structuredClone(await this.chapters)
      const searchResults = await Promise.all(this.book.spine.spineItems.map((item) => item.load(this.book.load.bind(this.book)).then(item.find.bind(item, query)).finally(item.unload.bind(item))))
      const mergedResults = [].concat(...searchResults)

      mergedResults.forEach((chapter) => {
        chapter.start = this.book.locations.percentageFromCfi(chapter.cfi)
        const foundChapter = this.findChapterFromPosition(chapters, chapter.start)
        if (foundChapter) foundChapter.searchResults.push(chapter)
      })

      let filteredResults = chapters.filter(function f(o) {
        if (o.searchResults.length) return true
        if (o.subitems.length) {
          return (o.subitems = o.subitems.filter(f)).length
        }
      })
      return filteredResults
    },
    keyUp(e) {
      if (!this.rendition) return
      const tag = (e.target?.tagName || '').toLowerCase()
      if (tag === 'input' || tag === 'textarea' || e.target?.isContentEditable) {
        return
      }
      const rtl = this.book?.package?.metadata?.direction === 'rtl'
      const code = e.keyCode || e.which
      if (code === 37 || code === 33) { // ArrowLeft or PageUp
        e.preventDefault()
        return rtl ? this.next() : this.prev()
      } else if (code === 39 || code === 34 || code === 32) { // ArrowRight or PageDown or Space
        e.preventDefault()
        return rtl ? this.prev() : this.next()
      }
    },
    /**
     * @param {object} payload
     * @param {string} payload.ebookLocation - CFI of the current location
     * @param {string} payload.ebookProgress - eBook Progress Percentage
     */
    updateProgress(payload) {
      if (!this.keepProgress) return
      this.$axios.$patch(`/api/me/progress/${this.libraryItemId}`, payload, { progress: false }).catch((error) => {
        console.error('EpubReader.updateProgress failed:', error)
      })
    },
    getAllEbookLocationData() {
      const locations = []
      let totalSize = 0 // Total in bytes

      for (const key in localStorage) {
        if (!localStorage.hasOwnProperty(key) || !key.startsWith('ebookLocations-')) {
          continue
        }

        try {
          const ebookLocations = JSON.parse(localStorage[key])
          if (!ebookLocations.locations) throw new Error('Invalid locations object')

          ebookLocations.key = key
          ebookLocations.size = (localStorage[key].length + key.length) * 2
          locations.push(ebookLocations)
          totalSize += ebookLocations.size
        } catch (error) {
          console.error('Failed to parse ebook locations', key, error)
          localStorage.removeItem(key)
        }
      }

      // Sort by oldest lastAccessed first
      locations.sort((a, b) => a.lastAccessed - b.lastAccessed)

      return {
        locations,
        totalSize
      }
    },
    /** @param {string} locationString */
    checkSaveLocations(locationString) {
      const maxSizeInBytes = 3000000 // Allow epub locations to take up to 3MB of space
      const newLocationsSize = JSON.stringify({ lastAccessed: Date.now(), locations: locationString }).length * 2

      // Too large overall
      if (newLocationsSize > maxSizeInBytes) {
        console.error('Epub locations are too large to store. Size =', newLocationsSize)
        return
      }

      const ebookLocationsData = this.getAllEbookLocationData()

      let availableSpace = maxSizeInBytes - ebookLocationsData.totalSize

      // Remove epub locations until there is room for locations
      while (availableSpace < newLocationsSize && ebookLocationsData.locations.length) {
        const oldestLocation = ebookLocationsData.locations.shift()
        console.log(`Removing cached locations for epub "${oldestLocation.key}" taking up ${oldestLocation.size} bytes`)
        availableSpace += oldestLocation.size
        localStorage.removeItem(oldestLocation.key)
      }

      console.log(`Cacheing epub locations with key "${this.localStorageLocationsKey}" taking up ${newLocationsSize} bytes`)
      this.saveLocations(locationString)
    },
    /** @param {string} locationString */
    saveLocations(locationString) {
      localStorage.setItem(
        this.localStorageLocationsKey,
        JSON.stringify({
          lastAccessed: Date.now(),
          locations: locationString
        })
      )
    },
    loadLocations() {
      const locationsObjString = localStorage.getItem(this.localStorageLocationsKey)
      if (!locationsObjString) return null

      const locationsObject = JSON.parse(locationsObjString)

      // Remove invalid location objects
      if (!locationsObject.locations) {
        console.error('Invalid epub locations stored', this.localStorageLocationsKey)
        localStorage.removeItem(this.localStorageLocationsKey)
        return null
      }

      // Update lastAccessed
      this.saveLocations(locationsObject.locations)

      return locationsObject.locations
    },
    /** @param {string} location - CFI of the new location */
    relocated(location) {
      if (location?.start?.cfi) {
        this.currentLocationKey = location.start.cfi
      }

      if (this.savedEbookLocation === location.start.cfi) {
        return
      }

      if (location.end.percentage) {
        this.updateProgress({
          ebookLocation: location.start.cfi,
          ebookProgress: location.end.percentage
        })
      } else {
        this.updateProgress({
          ebookLocation: location.start.cfi
        })
      }
    },
    initEpub() {
      /** @type {EpubReader} */
      const reader = this

      // Use axios to make request because we have token refresh logic in interceptor
      const customRequest = async (url) => {
        try {
          return this.$axios.$get(url, {
            responseType: 'arraybuffer'
          })
        } catch (error) {
          console.error('EpubReader.initEpub customRequest failed:', error)
          throw error
        }
      }

      /** @type {ePub.Book} */
      reader.book = new ePub(reader.ebookUrl, {
        width: this.readerWidth,
        height: this.readerHeight - 50,
        openAs: 'epub',
        requestMethod: customRequest
      })

      /** @type {ePub.Rendition} */
      reader.rendition = reader.book.renderTo('viewer', {
        width: this.readerWidth,
        height: this.readerHeight * 0.8,
        allowScriptedContent: this.allowScriptedContent,
        spread: 'auto',
        snap: true,
        manager: 'continuous',
        flow: 'paginated'
      })

      // load saved progress
      reader.rendition.display(this.savedEbookLocation || reader.book.locations.start)

      if (reader.rendition.hooks?.content) {
        reader.rendition.hooks.content.register((contents) => {
          this.setupLinks(contents)
        })
      }

      reader.rendition.on('rendered', () => {
        this.applyTheme()
      })

      reader.book.ready
        .then(() => {
          // set up event listeners
          reader.rendition.on('relocated', reader.relocated)
          reader.rendition.on('keydown', reader.keyUp)

          reader.rendition.on('touchstart', (event) => {
            this.$emit('touchstart', event)
          })
          reader.rendition.on('touchend', (event) => {
            this.$emit('touchend', event)
          })

          // load ebook cfi locations
          const savedLocations = this.loadLocations()
          if (savedLocations) {
            reader.book.locations.load(savedLocations)
          } else {
            reader.book.locations.generate().then(() => {
              this.checkSaveLocations(reader.book.locations.save())
            })
          }
          this.getChapters()
        })
        .catch((error) => {
          console.error('EpubReader.initEpub failed:', error)
        })
    },
    getChapters() {
      // Load the list of chapters in the book. See https://github.com/futurepress/epub.js/issues/759
      const toc = this.book?.navigation?.toc || []

      const tocTree = []

      const resolveURL = (url, relativeTo) => {
        // see https://github.com/futurepress/epub.js/issues/1084
        // HACK-ish: abuse the URL API a little to resolve the path
        // the base needs to be a valid URL, or it will throw a TypeError,
        // so we just set a random base URI and remove it later
        const base = 'https://example.invalid/'
        return new URL(url, base + relativeTo).href.replace(base, '')
      }

      const basePath = this.book.packaging.navPath || this.book.packaging.ncxPath

      const createTree = async (toc, parent) => {
        const promises = toc.map(async (tocItem, i) => {
          const href = resolveURL(tocItem.href, basePath)
          const id = href.split('#')[1]
          const item = this.book.spine.get(href)
          await item.load(this.book.load.bind(this.book))
          const el = id ? item.document.getElementById(id) : item.document.body

          const cfi = item.cfiFromElement(el)

          parent[i] = {
            title: tocItem.label.trim(),
            subitems: [],
            href,
            cfi,
            start: this.book.locations.percentageFromCfi(cfi),
            end: null, // set by flattenChapters()
            id: null, // set by flattenChapters()
            searchResults: []
          }

          if (tocItem.subitems) {
            await createTree(tocItem.subitems, parent[i].subitems)
          }
        })
        await Promise.all(promises)
      }
      return createTree(toc, tocTree).then(() => {
        this.chapters = tocTree
      })
    },
    flattenChapters(chapters) {
      // Convert the nested epub chapters into something that looks like audiobook chapters for player-ui
      const unwrap = (chapters) => {
        return chapters.reduce((acc, chapter) => {
          return chapter.subitems ? [...acc, chapter, ...unwrap(chapter.subitems)] : [...acc, chapter]
        }, [])
      }
      let flattenedChapters = unwrap(chapters)

      flattenedChapters = flattenedChapters.sort((a, b) => a.start - b.start)
      for (let i = 0; i < flattenedChapters.length; i++) {
        flattenedChapters[i].id = i
        if (i < flattenedChapters.length - 1) {
          flattenedChapters[i].end = flattenedChapters[i + 1].start
        } else {
          flattenedChapters[i].end = 1
        }
      }
      return flattenedChapters
    },
    resize() {
      this.windowWidth = window.innerWidth
      this.windowHeight = window.innerHeight
      this.rendition?.resize(this.readerWidth, this.readerHeight * 0.8)
    },
    setupLinks(contents) {
      if (!contents || !contents.document) return
      try {
        contents.document.querySelectorAll('a').forEach((link) => {
          link.style.cursor = 'pointer'
          link.onclick = (e) => {
            e.preventDefault()
            e.stopPropagation()
            const href = link.getAttribute('href') || ''
            this.handleLinkClick(href, link, contents)
          }
        })
      } catch (err) {
        console.warn('Error configuring EPUB links:', err)
      }
    },
    async handleLinkClick(href, link, contents) {
      if (!href) return
      const title = link.textContent.trim() || 'Riferimento'

      // 1. Collegamento Web Esterno
      if (href.startsWith('http://') || href.startsWith('https://') || href.startsWith('mailto:')) {
        this.activeLinkPopup = {
          type: 'external',
          title: title || 'Collegamento Esterno',
          url: href,
          content: href
        }
        return
      }

      // 2. Nota / Riferimento Interno (Footnote / Capitolo / Sezione)
      const hashIndex = href.indexOf('#')
      const targetId = hashIndex >= 0 ? href.substring(hashIndex + 1) : null
      let noteContent = ''

      // Cerca prima nel documento HTML corrente dell'EPUB
      if (targetId && contents?.document) {
        const targetEl = contents.document.getElementById(targetId) ||
                         contents.document.querySelector(`[id="${targetId}"]`) ||
                         contents.document.querySelector(`[name="${targetId}"]`)
        if (targetEl) {
          noteContent = targetEl.innerHTML || targetEl.innerText
        }
      }

      // Se non è nel documento corrente, cerca nello spine dell'EPUB
      if (!noteContent && this.book?.spine) {
        const filePath = hashIndex >= 0 ? href.substring(0, hashIndex) : href
        try {
          const item = this.book.spine.get(filePath || href)
          if (item) {
            await item.load(this.book.load.bind(this.book))
            if (targetId && item.document) {
              const el = item.document.getElementById(targetId) ||
                         item.document.querySelector(`[id="${targetId}"]`) ||
                         item.document.querySelector(`[name="${targetId}"]`)
              if (el) {
                noteContent = el.innerHTML || el.innerText
              }
            }
            if (!noteContent && item.document?.body) {
              noteContent = item.document.body.innerText.substring(0, 500) + '...'
            }
          }
        } catch (e) {
          console.warn('Error loading spine link content:', e)
        }
      }

      this.activeLinkPopup = {
        type: 'footnote',
        title: title || 'Nota di Riferimento',
        content: noteContent || `Riferimento: ${href}`,
        href
      }
    },
    openExternalUrl(url) {
      if (url) {
        window.open(url, '_blank', 'noopener,noreferrer')
      }
      this.activeLinkPopup = null
    },
    goToLinkHref(href) {
      if (href && this.rendition) {
        this.rendition.display(href)
      }
      this.activeLinkPopup = null
    },
    applyTheme() {
      if (!this.rendition) return
      this.rendition.getContents().forEach((c) => {
        c.addStylesheetRules(this.themeRules)
        this.setupLinks(c)
      })
    }
  },
  mounted() {
    this.windowWidth = window.innerWidth
    this.windowHeight = window.innerHeight
    window.addEventListener('resize', this.resize)
    window.addEventListener('keydown', this.keyUp)
    this.initEpub()
  },
  beforeDestroy() {
    window.removeEventListener('resize', this.resize)
    window.removeEventListener('keydown', this.keyUp)
    this.book?.destroy()
  }
}
</script>
