const express = require('express')
const app = express()
const port = 8888

app.get('/', (req, res) => {
  res.send('Hello World FROM V2 !')
})

app.listen(port, () => {
  console.log(`app listening on port ${port}`)
})