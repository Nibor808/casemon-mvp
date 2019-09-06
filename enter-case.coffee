session = require 'express-session'
knex = require '../knexa'
request = require 'request'
http_proxyArr = ['proxies']
UAArr = ['Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36', 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.2661.102 Safari/537.36', 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:40.0) Gecko/20100101 Firefox/40.1', 'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36']
cheerio = require 'cheerio'
nodemailer = require 'nodemailer'


module.exports = {

  enterCase : (req, res) ->
      caseId = req.body.caseNum
      caseType = req.body.caseType
      notes = req.body.notes
      email = req.body.emails
      phone = req.body.phones
      parties = req.body.parties
      concatCaseId = caseType + caseId

      sess = req.session
      user = sess.username
      date = new Date()
      dateTrim = date.toLocaleString()
      console.log user
      if caseType == "D" || caseType == "SD"
        url = 'http://www.ventura.courts.ca.gov/FamilyCaseSearch/CaseReport/' + caseType + '/' + caseId
      else
        url = 'https://www.lacourt.org/CaseSummary/UI/casesummary.aspx?' + caseId

      knex('cases').where('username', user).count('username as num')
        .then (data) ->
          for i in data
            numCases = i['num']

          if numCases >= 50
            res.send 'over limit'
          else
            knex('cases').where('username', user).insert({username: user, updated: dateTrim ,caseid: concatCaseId, url: url, notes: notes, notifemail: email, notifphone: phone, clientslawyers: parties})
              .then (data) ->
                res.send true
              .catch (err) ->
                console.log err.message
                res.send false


  checkCase : (req, res) ->
      caseType = req.body.caseType
      caseId = req.body.caseNum
      user = req.session.username
      console.log caseType
      if caseType == undefined
        la = true
        url = 'http://www.lacourt.org/casesummary/ui/casesummary.aspx?' + caseId
      else
        la = false
        url = 'http://www.ventura.courts.ca.gov/FamilyCaseSearch/CaseReport/' + caseType + '/' + caseId

      UA = UAArr[Math.floor(Math.random()*UAArr.length)]

      http_proxy = http_proxyArr[Math.floor(Math.random()*http_proxyArr.length)]

      options = {
        url: url,
        proxy: http_proxy,
        headers: {
          'User-Agent': UA,
          Referer: 'http://www.ventura.courts.ca.gov/FamilyCaseSearch/CaseNumber'
        }
      }

      buf = ''
      console.log 'la true?: ' + la
      console.log url
      if la == false
        request(options, (error, response, body) ->
          if error
            console.log error.message
            res.send error.message
          else
            resp = JSON.parse(JSON.stringify(response))
            code = resp['statusCode']

            buf += body.toString()

            $ = cheerio.load(buf)
            #console.log 'buf: ' + buf
            clients = $('#resultscontainer > h4').text()
            index = clients.indexOf('-')
            clientsTrim = clients.substr(index + 2)
            #console.log 'c: ' + clients
            info = $('#resultscontainer > p').text()
            #console.log 'i: ' + info

            if info == 'No results found'
              res.send false
            else
              knex('cases').where('username', user).select('notifemail')
                .then (data) ->
                  console.log data
                  res.send clientsTrim
        )
      else
        request(options, (error, response, body) ->
          if error
            console.log error.message
            res.send error.message
          else
            buf += body.toString()

            $ = cheerio.load(buf)
            clients = $('#resultscontainer > h4').text()
            index = clients.indexOf('-')
            clientsTrim = clients.substr(index + 2)
            info = $('#divMainContent > div > div.contentText > Form1').text() #divMainContent > div
            console.log 'info: ' + info
            for i in info
              text = i['data']

            if text == 'No results found'
              res.send false
            else
              res.send clientsTrim
      )


  enterTimeoutCase : (req, res) ->
    caseId = req.body.caseNum
    caseType = req.body.caseType
    notes = req.body.notes
    email = req.body.emails
    phone = req.body.phones
    concatCaseId = caseType + caseId

    sess = req.session
    user = sess.username

    if caseType == "D" || caseType == "SD"
      url = 'http://www.ventura.courts.ca.gov/FamilyCaseSearch/CaseReport/' + caseType + '/' + caseId
    else
      url = 'https://www.lacourt.org/CaseSummary/UI/casesummary.aspx?' + caseId

    knex('timeout').insert({username: user, caseid: concatCaseId, url: url, notes: notes, notifemail: email, notifphone: phone})
      .then (data) ->
        res.send true
        console.log 'saved timeout info'

      .catch (err) ->
        res.send false
        console.log 'got here'
        console.log err.message


  sendAlert : (req, res) ->
    user = req.session.username

    smtpConfig = {
      host: 'smtp.sendgrid.net',
      port: 587,
      secure: false, #use tls
      auth: {
        user: 'casemon',
        pass: 'pass'
      }
    }

    transporter = nodemailer.createTransport(smtpConfig)

    mailList = process.env.ADMIN_EMAILS

    mailList.forEach (to) ->
      mailData = {
        from: 'casemon@casemon.com',
        subject: 'ERROR ENTERING CASE FOR USER: ' + user,
        text: 'Timeout when checking case validity in enter-case'
      }
      mailData.to = to

      transporter.sendMail(mailData, (err, info) ->
        if err
          console.log err.message
          smtpConfig = {
            host: 'mail.vpop.net',
            port: 465,
            secure: true, #use ssl
            auth: {
              user: 'user',
              pass: 'pass'
            }
          }

          transporter = nodemailer.createTransport(smtpConfig)

          mailList = process.env.ADMIN_EMAILS

          mailList.forEach (to) ->
            mailData = {
              from: 'casemon@casemon.com',
              subject: 'ERROR ENTERING CASE FOR USER: ' + user,
              text: 'Timeout when checking case validity in enter-case. Message came from backup email.'
            }
            mailData.to = to

            transporter.sendMail(mailData, (err, info) ->
              if err
                console.log err.message
              else
                console.log 'Message sent ' + info.response
            )

        else
          console.log 'Message sent ' + info.response
      )
}