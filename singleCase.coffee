limit = require 'simple-rate-limiter'
request = limit(require 'request').to(1).per(10000)
cheerio = require 'cheerio'
fs = require 'fs'
md5 = require 'md5'
knex = require '../knexa'
nodemailer = require 'nodemailer'
jsdiff = require 'diff'
http_proxy = 'proxy'
plivo = require 'plivo'
p = plivo.RestAPI({
    authId: 'plivioAuth',
    authToken: 'plivioAuthToken'
})

module.exports = {

  #htmlChangeArr : []
  totalCheckCounterArr : []
  #changeCounterArr : []
  scrapeCheckCounterArr : []
  scrapeChangeCounterArr : []
  userCheckCounterArr : []
  userChangeCounterArr : []
  totalCasesCounter : 0
  timeStart : ""
  timeStop : ""

  scrape : (req,res) ->

    caseId = 'D374854'
    knex('cases').where('caseid', caseId).select('url', 'clientslawyers', 'savedMd5')
      .then (data) ->
        counter = 0
        totalCasesCounter = 0
        changeCounter = 0
        totalCheckCounter = 0
        userCheckCounter = 0
        userChangeCounter = 0
        scrapeCheckCounter = 0
        scrapeChangeCounter = 0
        totalCheckCounterArr = []
        userCheckCounterArr = []
        #changeCounterArr = []
        userChangeCounterArr = []
        scrapeCheckCounterArr = []
        scrapeChangeCounterArr = []
        htmlChangeArr = []
        dateStart = new Date()
        module.exports.timeStart = dateStart.toLocaleString()

        data.forEach (i) ->
          url = i['url']
          savedMd5 = i['savedMd5']
          clientslawyers = i['clientslawyers']
          totalCasesCounter++

          options = {
              url: url,
              proxy: http_proxy
          }

          buf = ''

          request(options, (error, response, body) ->
            if error
              console.log error.message
            else
              buf += body.toString()

              date = new Date()
              time = date.getTime()
              dateTrim = date.toLocaleString()
              day = date.getDate()
              month = date.getMonth() + 1
              year = date.getFullYear()
              fullDate = month + '/' + day + '/' + year

              $ = cheerio.load(buf)
              info = $('#resultscontainer')

              output = md5(info)

              totalCheckCounter++
              module.exports.totalCheckCounterArr.push totalCheckCounter

              if totalCheckCounter = totalCasesCounter
                timeStopDate = new Date()
                module.exports.timeStop = timeStopDate.toLocaleString()

              knex('cases').where('caseid', caseId).select('username')
                .then (data) ->

                  data.forEach (i) ->
                    user = i['username']
                    console.log 'user: ' + user
                    if user == 'scrape'
                      scrapeCheckCounter++
                      module.exports.scrapeCheckCounterArr.push scrapeCheckCounter
                      console.log 'inserted scrape check'
                    else
                      userCheckCounter++
                      module.exports.userCheckCounterArr.push userCheckCounter
                      knex('userchecks').insert({date: fullDate, username: user, usercheck: '1'})
                        .then (data) ->
                          console.log 'inserted user check'


                #d41d8cd98f00b204e9800998ecf8427e = request timed out
                if output == 'd41d8cd98f00b204e9800998ecf8427e' || savedMd5 != null && savedMd5 == output
                  knex('cases').where({caseid: caseId}).update(updated: dateTrim)
                    .then (data) ->
                      counter = 0

                      console.log 'same or timeout error'
                      # logging
                      fs.writeFile('./md5/log'+ caseId, output + ' no change ' + dateTrim, {flag: 'wx'}, (err) ->
                        if err
                          fs.appendFile('./md5/log'+ caseId, '\n' + output + ' no change ' + dateTrim, (err) ->
                            if err
                              console.log err.message
                            else
                              console.log 'appended md5'
                          )
                          console.log err.message
                        else
                          console.log 'saved'
                      )

                else if savedMd5 == null
                  knex('cases').where({caseid: caseId}).update({savedMd5: output, updated: dateTrim})
                    .then (data) ->
                      counter = 0
                      console.log 'updated record: ' + data + ' counter: ' + counter
                      # logging
                      fs.writeFile('./md5/log'+ caseId, output + ' new entry ' + dateTrim, {flag: 'wx'}, (err) ->
                        if err
                          fs.appendFile('./md5/log'+ caseId, '\n' + output + ' new entry ' + dateTrim, (err) ->
                              if err
                                  console.log err.message
                              else
                                  console.log 'appended md5'
                          )
                          console.log err.message
                        else
                          console.log 'saved'
                      )

                      knex('cases').where({caseid: caseId}).update('oldhtml', './htmlLog/log'+ caseId)
                        .then (data) ->
                          fs.writeFile('./htmlLog/log'+ caseId, dateTrim + '\n' + info, {flag: 'wx'}, (err) ->
                            if err
                              console.log err.message
                            else
                              console.log 'saved html'
                          )

                  else if savedMd5 != null && savedMd5 != output
                    counter++

                    knex('cases').where({caseid: caseId}).update({savedMd5: output, updated: dateTrim})
                      .then (data) ->
                        console.log 'different ' + 'counter: ' + counter
                        # logging
                        fs.writeFile('./md5/log'+ caseId, output + ' CHANGE DETECTED ' + dateTrim, {flag: 'wx'}, (err) ->
                          if err
                            fs.appendFile('./md5/log'+ caseId, '\n' + output + ' CHANGE DETECTED ' + dateTrim, (err) ->
                              if err
                                console.log err.message
                              else
                                console.log 'appended md5'
                            )
                            console.log err.message
                          else
                            console.log 'saved'
                        )

                      knex('cases').where({caseid: caseId}).select('oldhtml')
                        .then (data) ->
                          for i in data
                            oldhtml = i['oldhtml']
                            console.log 'got it'

                          cOldS = ''
                          cNewS = ''
                          val = ''
                          rd = fs.writeFileSync('./htmlLog/log'+ caseId, info, {flag: 'wx'}, (err) ->
                            if err
                              console.log err.message
                            else
                              console.log 'saved new html'
                          )
                          cNew = rd#'./htmlLog/log'+ caseId
                          #oldhtmlPlus = '.' + oldhtml

                          contentOld = fs.readFileSync(oldhtml)
                          cOldS = contentOld.toString()
                          console.log 'done old'

                          contentNew = fs.readFileSync(cNew)
                          cNewS = contentNew.toString()
                          console.log 'done new'

                          diff = jsdiff.diffTrimmedLines(cOldS, cNewS)

                          diff.forEach (i) ->
                            added = i.added
                            console.log 'added?: ' + i.added

                            if added == true
                              val = i.value
                              valS = val.toString()
                              console.log 'VAL: ' + valS

                              first = valS.indexOf("<td>", 0) + 4


                              cPartParse = valS.substring(first)
                              last = cPartParse.indexOf("</td>", 0)
                              cPartParseFinal = cPartParse.substring(0, last)
                              console.log 'PART PARSE: ' + cPartParseFinal

                              htmlChangeArr.push cPartParseFinal
                              console.log 'PART PARSE Arr: ' + htmlChangeArr

                              knex('cases').where('caseid', caseId).update('oldhtml', cNew)
                                  .then (data) ->
                                      console.log 'updated html'
                                      #console.log 'PART PARSE 1: ' + htmlChangeArr[1]


                    if counter >= 3

                      smtpConfig = {
                        host: 'smtp.sendgrid.net',
                        port: 587,
                        secure: false, # use tls
                        auth: {
                            user: 'casemon',
                            pass: 'pass'
                        }
                      }

                      transporter = nodemailer.createTransport(smtpConfig)

                      mailData = {
                        from: 'casemon@casemon.com',
                        to: 'my_email',
                        subject: 'Too many changes',
                        text: 'Too many changes'
                      }

                      transporter.sendMail(mailData, (err, info) ->
                        if err
                          console.log err.message
                        else
                          console.log 'Message sent ' + info.response
                      )

                      params = {
                        'src' : 'sms_number',
                        'dst' : 'my_phone',
                        'text' : 'Too many changes',
                        'url' : 'http://casemon.com/smsresponse',
                        'method' : 'GET'
                      }

                      p.send_message(params, (status, response) ->
                        console.log 'sms sent'
                        console.log 'Status: ', status
                        console.log 'API Response:\n', response
                        console.log 'Message UUID:\n', response['message_uuid']
                        console.log 'Api ID:\n', response['api_id']
                      )
                      return

                    else

                      # changeCounter++
                      # module.exports.changeCounterArr.push changeCounter
                      knex('cases').where('caseid', caseId).select('username', 'notifemail', 'notifphone')
                        .then (data) ->
                          for i in data
                            user = i['username']
                            email = i['notifemail']
                            phone = i['notifphone']

                            module.exports.notify(email, caseId, user, url, phone, clientslawyers, htmlChangeArr)
                            console.log 'user: ' + user
                            if user == 'scrape'
                              scrapeChangeCounter++
                              module.exports.scrapeChangeCounterArr.push scrapeChangeCounter
                              console.log 'inserted scrape change'
                            else
                              userChangeCounter++
                              module.exports.userChangeCounterArr.push userChangeCounter
                              knex('userchecks').insert({date: fullDate, username: user, userchange: '1'})
                                .then (data) ->
                                  console.log 'inserted user change'
          )


  runReport :  ->

    totalChecks = module.exports.totalCheckCounterArr.length
    #changes = module.exports.changeCounterArr.length
    scrapeChecks = module.exports.scrapeCheckCounterArr.length
    scrapeChanges = module.exports.scrapeChangeCounterArr.length
    userChecks = module.exports.userCheckCounterArr.length
    userChanges = module.exports.userChangeCounterArr.length
    startTime = module.exports.timeStart
    stopTime = module.exports.timeStop

    date = new Date()
    dateTrim = date.toLocaleString()
    day = date.getDate()
    month = date.getMonth() + 1
    year = date.getFullYear()
    fullDate = month + '/' + day + '/' + year

    knex('reports').insert({date: dateTrim, day: fullDate, checks: totalChecks, userchecks: userChecks, scrapechecks: scrapeChecks, userchanges: userChanges, scrapechanges: scrapeChanges,})
      .then (data) ->
        console.log 'run report'

    smtpConfig = {
      host: 'smtp.sendgrid.net',
      port: 587,
      secure: false, # use tls
      auth: {
        user: 'casemon',
        pass: 'pass'
      }
    }

    transporter = nodemailer.createTransport(smtpConfig)

    mailList = ['admin_emails']

    mailList.forEach (to) ->
      mailData = {
        from: 'casemon@casemon.com',
        subject: 'Run Report ' + dateTrim,
        html: 'Start Time: ' + startTime + '<br />' + 'Finish Time: ' + stopTime + '<br />' + 'Total cases checked for this run: ' + totalChecks + '<br />' + 'Total checks for users(not named "scrape"): ' + userChecks + '<br />' + 'Total checks for user "Scrape": ' + scrapeChecks + '<br />' + 'Total changes for users(not named "scrape"): ' + userChanges + '<br />' + 'Total changes for user "Scrape": ' + scrapeChanges
      }
      mailData.to = to

      transporter.sendMail(mailData, (err, info) ->
        if err
          console.log err.message
          #backup email
          smtpConfig = {
            host: 'host',
            port: 587,
            secure: true, # don't use tls
            auth: {
              user: 'user',
              pass: 'pass'
            }
          }

          transporter = nodemailer.createTransport(smtpConfig)

          mailList = ['admin_emails']

          mailList.forEach (to) ->
            mailData = {
              from: 'casemon@casemon.com',
              subject: 'Run Report ' + dateTrim,
              html: 'Start Time: ' + startTime + '<br />' + 'Finish Time: ' + stopTime + '<br />' + 'Total cases checked for this run: ' + totalChecks + '<br />' + 'Total checks for users(not named "scrape"): ' + userChecks + '<br />' + 'Total checks for user "Scrape": ' + scrapeChecks + '<br />' + 'Total changes for users(not named "scrape"): ' + userChanges + '<br />' + 'Total changes for user "Scrape": ' + scrapeChanges
            }
            mailData.to = to

            transporter.sendMail(mailData, (err, info) ->
              if err
                console.log err.message
              else
                console.log 'Message sent ' + info.response
            )

          payload = {
            text: '*Run Report*' + '\n' + 'Start Time: ' + startTime + '\n' + 'Finish Time: ' + stopTime + '\n' + 'Total cases checked for this run: ' + totalChecks + '\n' + 'Total checks for users(not named "scrape"): ' + userChecks + '\n' + 'Total checks for user "Scrape": ' + scrapeChecks + '\n' + 'Total changes for users(not named "scrape"): ' + userChanges + '\n' + 'Total changes for user "Scrape": ' + scrapeChanges
          }

          options = {
            url:"chatURL",
            proxy: http_proxy,
            method: 'POST',
            contentType: 'application/json',
            body: JSON.stringify(payload)
          }

          request(options, (err, response, body) ->
            if err
              console.log err.message
            else
              console.log 'done'
          )
        else
          console.log 'Message sent ' + info.response

      )

    payload = {
      text: '*Run Report*' + '\n' + 'Start Time: ' + startTime + '\n' + 'Finish Time: ' + stopTime + '\n' + 'Total cases checked for this run: ' + totalChecks + '\n' + 'Total checks for users(not named "scrape"): ' + userChecks + '\n' + 'Total checks for user "Scrape": ' + scrapeChecks + '\n' + 'Total changes for users(not named "scrape"): ' + userChanges + '\n' + 'Total changes for user "Scrape": ' + scrapeChanges
    }

    options = {
      url:"chatURL",
      proxy: http_proxy,
      method: 'POST',
      contentType: 'application/json',
      body: JSON.stringify(payload)
    }

    request(options, (err, response, body) ->
      if err
        console.log err.message
      else
        console.log 'done'
    )



  eodReport : ->

    date = new Date()
    day = date.getDate()
    month = date.getMonth() + 1
    year = date.getFullYear()
    fullDate = month + '/' + day + '/' + year

    knex('reports').where('day', fullDate).sum('checks as totalChecks').sum('userchecks as userChecks').sum('userchanges as userChanges').sum('logins as logins').sum('logouts as logouts').sum('signups as signups').sum('scrapechecks as scrapeChecks').sum('scrapechanges as scrapeChanges')
      .then (data) ->
        for i in data
          totalChecks = i['totalChecks']
          userChecks = i['userChecks']
          userChanges = i['userChanges']
          scrapeChecks = i['scrapeChecks']
          scrapeChanges = i['scrapeChanges']
          logins = i['logins']
          logouts = i['logouts']
          signups = i['signups']

        smtpConfig = {
          host: 'smtp.sendgrid.net',
          port: 587,
          secure: false, # use tls
          auth: {
            user: 'casemon',
            pass: 'sendgridPass'
          }
        }

        transporter = nodemailer.createTransport(smtpConfig)

        mailList = ['admin_emails']

        mailList.forEach (to) ->
          mailData = {
            from: 'casemon@casemon.com',
            subject: 'EOD Report ' + fullDate,
            html: 'Total cases checked for today: ' + totalChecks + '<br />' + 'Total checks for users (not named "scrape") today: ' + userChecks + '<br />' + 'Total checks for user "Scrape" today: ' + scrapeChecks + '<br />' + 'Total changes for users (not named "scrape") today: ' + userChanges + '<br />' + 'Total changes for user "Scrape" today: ' + scrapeChanges + '<br />' + 'Logins for today: ' + logins + '<br />' + 'Logouts for today: ' + logouts + '<br />' + 'New Sign-ups for today: ' + signups
          }
          mailData.to = to

          transporter.sendMail(mailData, (err, info) ->
            if err
              console.log err.message
              #backup email
              smtpConfig = {
                host: 'host',
                port: 587,
                secure: true, # don't use tls
                auth: {
                  user: 'user',
                  pass: 'pass'
                }
              }

              transporter = nodemailer.createTransport(smtpConfig)

              mailList = ['admin_emails']

              mailList.forEach (to) ->
                mailData = {
                  from: 'casemon@casemon.com',
                  subject: 'EOD Report ' + fullDate,
                  html: 'Total cases checked for today: ' + totalChecks + '<br />' + 'Total checks for users (not named "scrape") today: ' + userChecks + '<br />' + 'Total checks for user "Scrape" today: ' + scrapeChecks + '<br />' + 'Total changes for users (not named "scrape") today: ' + userChanges + '<br />' + 'Total changes for user "Scrape" today: ' + scrapeChanges + '<br />' + 'Logins for today: ' + logins + '<br />' + 'Logouts for today: ' + logouts + '<br />' + 'New Sign-ups for today: ' + signups
                }
                mailData.to = to

                transporter.sendMail(mailData, (err, info) ->
                  if err
                    console.log err.message
                  else
                    console.log 'Message sent ' + info.response
                )

              payload = {
                text:  '*EOD Report*' + '\n' + 'Total cases checked for today: ' + totalChecks + '\n' + 'Total checks for users (not named "scrape") today: ' + userChecks + '\n' + 'Total checks for user "Scrape" today: ' + scrapeChecks + '\n' + 'Total changes for users (not named "scrape") today: ' + userChanges + '\n' + 'Total changes for user "Scrape" today: ' + scrapeChanges + '\n' + 'Logins for today: ' + logins + '\n' + 'Logouts for today: ' + logouts + '\n' + 'New Sign-ups for today: ' + signups
              }

              options = {
                url:"chatURL",
                proxy: http_proxy,
                method: 'POST',
                contentType: 'application/json',
                body: JSON.stringify(payload)
              }

              request(options, (err, response, body) ->
                if err
                  console.log err.message
                else
                  console.log 'done'
              )

            else
              console.log 'Message sent ' + info.response
          )

          payload = {
            text:  '*EOD Report*' + '\n' + 'Total cases checked for today: ' + totalChecks + '\n' + 'Total checks for users (not named "scrape") today: ' + userChecks + '\n' + 'Total checks for user "Scrape" today: ' + scrapeChecks + '\n' + 'Total changes for users (not named "scrape") today: ' + userChanges + '\n' + 'Total changes for user "Scrape" today: ' + scrapeChanges + '\n' + 'Logins for today: ' + logins + '\n' + 'Logouts for today: ' + logouts + '\n' + 'New Sign-ups for today: ' + signups
          }

          options = {
            url:"chatURL",
            proxy: http_proxy,
            method: 'POST',
            contentType: 'application/json',
            body: JSON.stringify(payload)
          }

          request(options, (err, response, body) ->
            if err
              console.log err.message
            else
              console.log 'done'
          )



  notify : (email, caseId, user, url, phone, clientslawyers, changeArr) ->

    if !phone
      # email for no phone number
      smtpConfig = {
        host: 'smtp.sendgrid.net',
        port: 587,
        secure: false, # use tls
        auth: {
          user: 'casemon',
          pass: 'pass'
        }
      }

      transporter = nodemailer.createTransport(smtpConfig)

      mailList = email.split(',')
      console.log 'mail1: ' + mailList[0]
      console.log 'mail2: ' + mailList[1]
      console.log 'user: ' + user
      console.log 'caseId: ' + caseId

      mailList.forEach (to) ->
        mailData = {
          from: 'casemon@casemon.com',
          subject: 'casemon alert: case ' + caseId + ' updated! ' + clientslawyers,
          html: 'We have detected an update to case ' + caseId + '. ' + '<a href=' + url + '>Click here to see it.</a> ' + '<br /><br />' + 'Parties: ' + clientslawyers + '<br /><br />' + 'Thanks for using casemon!'
        }
        mailData.to = to

        transporter.sendMail(mailData, (err, info) ->
          if err
            console.log err.message
            module.exports.backupEmail(email, caseId, user, url, clientslawyers)
            module.exports.adminNotifyEmailProblem(email, user, err.message)
          else
            console.log 'Message sent ' + info.response + ' email: ' + mailList[0] + ' ' + mailList[1]
        )

    else
      #email
      smtpConfig = {
        host: 'smtp.sendgrid.net',
        port: 587,
        secure: false, # not tls
        auth: {
          user: 'casemon',
          pass: 'pass'
        }
      }

      transporter = nodemailer.createTransport(smtpConfig)

      mailList = email.split(',')
      console.log 'mail1: ' + mailList[0]
      console.log 'mail2: ' + mailList[1]
      console.log 'user: ' + user
      console.log 'caseId: ' + caseId

      changeArr.forEach (d, i) ->
        if d != ''
          changedPart = i + ')' + ' ' + d
          console.log 'notify part: ' + changedPart

          mailList.forEach (to) ->
            mailData = {
                    from: 'casemon@casemon.com',
                    subject: 'casemon alert: case ' + caseId + ' updated! ' + clientslawyers,
                    html: 'We have detected an update to case ' + caseId + '. ' + '<a href=' + url + '>Click here to see it.</a> ' + '<br /><br />' + 'Parties: ' + clientslawyers + '<br /><br />' + '<br /><br />Update: ' + changedPart + '<br /><br />' + 'Thanks for using casemon!'
                }
            mailData.to = to

            transporter.sendMail(mailData, (err, info) ->
                if err
                    console.log err.message
                    module.exports.backupEmail(email, caseId, user, url, clientslawyers)
                    module.exports.adminNotifyEmailProblem(email, user, err.message)
                else
                    console.log 'Message sent ' + info.response + ' email: ' + mailList[0] + ' ' + mailList[1]
            )

            #sms
            console.log 'phone: ' + phone
            phones = phone.split(',')
            phoneList = []
            console.log 'phoneList: ' + phoneList

            if phones[1] == undefined
              phoneNumOne = phones[0].replace(/\D/g, '')
              phoneList.push(phoneNumOne)
            else
              phoneNumOne = phones[0].replace(/\D/g, '')
              phoneNumTwo = phones[1].replace(/\D/g, '')
              phoneList.push(phoneNumOne)
              phoneList.push(phoneNumTwo)

            phoneList.forEach (dst) ->
              params = {
                'src' : 'sms_phone',
                'text' : 'We have detected an update to case ' + caseId + '. ' + clientslawyers + ' ' + url + ' Update: ' + changedPart,
                'url' : 'http://casemon.com/smsresponse',
                'method' : 'GET'
              }
              params.dst = dst

              p.send_message(params, (status, response) ->
                console.log 'sms sent' + ' phone: ' + phoneList
                console.log 'Status: ', status
                console.log 'API Response:\n', response
                console.log 'Message UUID:\n', response['message_uuid']
                console.log 'Api ID:\n', response['api_id']
              )



  backupEmail : (email, caseId, user, url, clientslawyers) ->

    smtpConfig = {
      host: 'host',
      port: 587,
      secure: true, # don't use tls
      auth: {
        user: 'user',
        pass: 'pass'
      }
    }

    transporter = nodemailer.createTransport(smtpConfig)

    mailList = email.split(',')

    mailList.forEach (to) ->
      mailData = {
        from: 'casemon@casemon.com',
        subject: 'casemon alert: case ' + caseId + ' updated! ' + clientslawyers,
        html: 'We have detected an update to case ' + caseId + '. ' + '<a href=' + url + '>Click here to see it.</a> ' + '<br /><br />' + 'Parties: ' + clientslawyers + '<br /><br />' + 'Thanks for using casemon!'
      }
      mailData.to = to

      transporter.sendMail(mailData, (err, info) ->
        if err
          console.log err.message
        else
          console.log 'Message sent ' + info.response
      )


  adminNotifyEmailProblem : (email, user, msg) ->

    smtpConfig = {
      host: 'host',
      port: 587,
      secure: true, # don't use tls
      auth: {
        user: 'user',
        pass: 'pass'
      }
    }

    transporter = nodemailer.createTransport(smtpConfig)

    mailList = ['admin_emails']

    mailList = email.split(',')

    mailList.forEach (to) ->
      mailData = {
        from: 'casemon@casemon.com',
        subject: 'ERROR WITH EMAIL FOR: ' + user,
        text: msg
      }
      mailData.to = to

      transporter.sendMail(mailData, (err, info) ->
        if err
          console.log err.message
        else
          console.log 'Message sent ' + info.response
      )


  sendDailyUserReport : ->

    date = new Date()
    day = date.getDate()
    month = date.getMonth() + 1
    year = date.getFullYear()
    fullDate = month + '/' + day + '/' + year

    knex('users').where('dailyemail', 'yes').select('username', 'email')
      .then (data) ->
        data.forEach (i) ->
          usersUser = i['username']
          email = i['email']

          knex('quotes').where('id', day).select('quote', 'author')
            .then (data) ->
              for i in data
                quote = i['quote']
                author = i['author']

                knex('userchecks').where({date: fullDate, username: usersUser}).sum('usercheck as checks').sum('userchange as changes')
                  .then (data) ->
                    for i in data
                      checks = i['checks']
                      changes = i['changes']

                      smtpConfig = {
                        host: 'smtp.sendgrid.net',
                        port: 587,
                        secure: false, # not tls
                        auth: {
                          user: 'casemon',
                          pass: 'pass'
                        }
                      }

                      transporter = nodemailer.createTransport(smtpConfig)

                      if changes == 0
                        html = 'Greetings,' + '<br /><br />' + 'Today we checked ' + checks + ' case(s) for you and there were no updates.' + '<br />' +  'You can disable this automated email in your casemon settings.' + '<br /><br />' + 'Thanks for using casemon!' + '<br /><br />' + '"' + quote + '"' + ' -' + author
                      else if changes == 1
                        html = 'Greetings,' + '<br /><br />' + 'Today we checked ' + checks + ' case(s) for you and there was ' + changes + ' update.' + '<br />' +  'You can disable this automated email in your casemon settings.' + '<br /><br />' + 'Thanks for using casemon!' + '<br /><br />' + '"' + quote + '"' + ' -' + author
                      else
                        html = 'Greetings,' + '<br /><br />' + 'Today we checked ' + checks + ' case(s) for you and there were ' + changes + ' updates.' + '<br />' +  'You can disable this automated email in your casemon settings.' + '<br /><br />' + 'Thanks for using casemon!' + '<br /><br />' + '"' + quote + '"' + ' -' + author

                      mailData = {
                        from: 'casemon@casemon.com',
                        subject: 'casemon daily report: ' + changes + ' updates',
                        to: email,
                        html: html
                      }

                      transporter.sendMail(mailData, (err, info) ->
                        if err
                          console.log err.message
                        else
                          console.log 'Message sent ' + info.response
                      )

}