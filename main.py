#!/usr/bin/env python
__version__ = "0.1"

from kivy.lang import Builder
from kivy.app import App
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.gridlayout import GridLayout
from kivy.uix.boxlayout import BoxLayout
from kivy.clock import Clock, mainthread
from threading import Thread
import SocketServer
from Queue import Queue

Builder.load_string("""
<RootWidget>:
    cols: 1
    orientation: 'vertical'
    canvas:
        Color:
            rgba: 0.1, 0.2, 0.3, 0.75
        Rectangle:
            pos: self.pos
            size: self.size

    label1: label1
    label2: label2
    label3: label3
    label4: label4
    label5: label5
    button_setup: button_setup

    Label:
        id: label1
        font_size: 36
        text: "Waiting for Node 1 data..."
        color: .95, .95, .5, 1

    Label:
        id: label2
        font_size: 36
        text: "Waiting for Node 2 data..."
        color: .95, .95, .5, 1

    Label:
        id: label3
        font_size: 36
        text: "Waiting for Node 3 data..."
        color: .95, .95, .5, 1

    Label:
        id: label4
        font_size: 36
        text: "Waiting for Node 4 data..."
        color: .95, .95, .5, 1

    Label:
        id: label5
        font_size: 36
        text: "Waiting for Node 5 data..."
        color: .95, .95, .5, 1

    Label:
        id: label6
        font_size: 36
        text: "Waiting for Node 6 data..."
        color: .95, .95, .5, 1

    Label:
        id: label7
        font_size: 36
        text: "Waiting for Node 7 data..."
        color: .95, .95, .5, 1

    Label:
        id: label8
        font_size: 36
        text: "Waiting for Node 8 data..."
        color: .95, .95, .5, 1



    Button:
        id: button_setup
        font_size: 20
        text: 'Setup'
        color: .95, .95, .5, 1
        background_color: .25, .25, .5, 1
""")

class RootWidget(BoxLayout):

    def __init__(self, q, **kwargs):
        super(RootWidget, self).__init__(**kwargs)
        self.q = q
        Clock.schedule_interval(self.q_watch, 0.5)


    def q_watch(self, *args):
        try:
            data = self.q.get_nowait()

            # format data
            payload = "Node %s Temp: %s'C RH: %s%%" % (data['id'], data['temp'], data['rh'])
            print payload

            # modify gui elements
            if data[0] == '1':
                self.label1.text = payload
            elif data[0] == '2':
                self.label2.text = payload
            elif data[0] == '3':
                self.label3.text = payload
            elif data[0] == '4':
                self.label4.text = payload
            elif data[0] == '5':
                self.label5.text = payload
            elif data[0] == '6':
                self.label6.text = payload
            elif data[0] == '7':
                self.label7.text = payload
            elif data[0] == '8':
                self.label8.text = payload
            else:
                print "Invalid data", data


class WebServer(SocketServer.ThreadingTCPServer):

    def __init__(self, options, q):
        self.running = True
        self.options = options
        self.q = q

        # connect to first available port
        port_low, port_high = self.options['port_range']
        for port in range(port_low, port_high):
            try:
                SocketServer.ThreadingTCPServer.__init__(self, ('', port), self.handler)
                break
            except:
                print "Port %s is busy..." % port
        print "Connected on port %s" % port

        self.timeout = 0.5


    def serve_until_stopped(self):
        fd = self.socket.fileno()
        import select
        while self.running:
            try:
                rd, wr, ex = select.select([fd], [], [], self.timeout)
            except Exception as e:
                print "Stopping"
                return False
            if rd:
                self.handle_request()

        # Shutting down
        self.socket.close()
        return False


    def handler(self, socket, tup, obj):
        src, port = tup
        print src,port
        raw = socket.recv(4096)
        try:
            print "RAW", raw
            raw = raw.split(' ')[1] # get payload element
            print "RAW", raw
            raw = raw.split('/') # skip leading slash
            print "RAW", raw
            raw = eval(raw[1][:-5])
        except:
            pass
        print "DATA", raw
        """GET / {'id':1,'Temp':23.5,'Humid':65.2} HTTP/1.1\r\nHost: x.x.x.x\r\nConnection: keep-alive\r\nAccept: */*\r\n\r\n"""

        # queue data
        self.q.put(data)


    def handle_request(self):
        try:
            socket = self.get_request()
            #print socket[0] # <socket._socketobject object at 0x7f6f8b9f6130>
            #print socket[1] # ('127.0.0.1', 36179)
            self.process_request(socket[0], socket[1])
        except Exception as e:
            print "FAILED:", e


class MyApp(App):

    def __init__(self, **kwargs):
        super(MyApp, self).__init__(**kwargs)

        # start with defaults
        self.options = {}
        self.options['port_range'] = (8000,9000)

        # thread shared queue
        self.q = Queue()

        self.t = Thread(target=self.t_server, args=([self.q,]))
        self.t.start()


    def t_server(self, q):
        self.webserver = WebServer(self.options, q)
        self.webserver.serve_until_stopped()
        return False


    def on_stop(self):
        """stop python thread before app stops"""
        self.webserver.running = False
        

    def build(self):
        return RootWidget(self.q)


if __name__ == "__main__":  
    MyApp().run()

