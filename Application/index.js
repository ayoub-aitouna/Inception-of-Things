const express = require('express')
const app = express()
const port = 8888

app.get('/', (req, res) => {
  res.send('Hello World!')
})

app.listen(port, () => {
  console.log(`aaitouna app listening on port ${port}`)
})