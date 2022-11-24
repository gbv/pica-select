<script setup>
import { onMounted, watch  } from "vue"

import  Prism from 'prismjs'
import 'prismjs/themes/prism.css'
import "../prism-pica.js"

const props = defineProps({ records: String })

const highlight = e => Prism.highlightElement(e)
onMounted(() => highlight(document.getElementById("pica-result")))
watch( () => props.records, pica => {
    // prism modified DOM as well, so inject again
    const div = document.getElementById("pica-result")
    const code = document.createElement("code")
    code.textContent = pica
    div.replaceChildren(code)
    highlight(div)
})
</script>

<template>
  <div>
    <pre class="language-pica" id="pica-result"><code>{{records}}</code></pre>
  </div>
</template>
