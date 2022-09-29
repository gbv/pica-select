<script setup>
defineProps({
  api: {
    type: String,
    required: true
  }
})

import { ref } from 'vue'

const apiStatus = ref(undefined)
</script>

<template>
    <form :action="`${api}/select`" method="get">
          <div>
            <label for="cql">CQL</label>
            <input type="text" name="cql" style="width: 80%;" />            
            <input type="submit" />
          </div>
          <div>
            <label for="format">Format</label>
            <select name="format">
              <option value="pp">PICA+ Plain</option>
              <option value="norm">PICA+ Normalized</option>
              <option value="json">JSON</option>
              <option value="tsv">TSV (ausgewählte Unterfelder)</option>
            </select>
            <label for="select">Unterfelder</label>
            <input type="text" name="select" />
          </div>
    </form>
  <div>
    API: <a :href="api">{{api}}</a>
    {{apiStatus}}
  </div>
  <div>...</div>
</template>

<script>
export default {
  mounted() {
    const statusEndpoint = this.api + "/select"
    fetch(statusEndpoint)
      .then(response => response.json())
      .then(res => this.apiStatus = res)
  }
}
</script>

<style scoped>
code {
  color: #d63384;
  word-wrap: break-word;
}
a > code {
  color: rgb(96, 143, 219);
}
pre {
  background-color: #f7f7f9;
  padding: 1em;
  margin: 0.3em 0;
}
pre > code {
  color: #000;
}
input, label {
  display: inline-block;
}
form {
  padding: 0.5em 0em 0em 0em;
}
.msg {
  background: #def;
  border-color: #59d;
}
.msg.valid {
  border-color: #2d2;
  background: #dfd;
}
.msg.invalid {
  border-color: #e44;
  background: #fdd;
}
</style>
