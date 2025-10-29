package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

type Instancia struct {
	Host  string `json:"host"`
	IP    string `json:"ip"`
	URL   string `json:"url"`
	Fecha string `json:"fecha"`
}

func solicitaciónHnandler(w http.ResponseWriter, r *http.Request) {

	if r.Method == http.MethodPost {
		host := r.FormValue("host")

		if host == "" {
			//necesito veriifcar que no haya otro hostname con el mismo nombre

			http.Redirect(w, r, "/", http.StatusSeeOther)
			return
		}
		//script creación maquina virtual

		//solicitud al dns (Bind) con host

	}
}

func publicarHandler(w http.ResponseWriter, r *http.Request) {
	// Parsear formulario
	err := r.ParseMultipartForm(32 << 20) // 32MB
	if err != nil {
		http.Error(w, "Error al parsear el formulario", http.StatusBadRequest)
		return
	}

	host := r.FormValue("host")
	file, handler, err := r.FormFile("contenido")
	if err != nil {
		http.Error(w, "Archivo no recibido", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// Guardar archivo temporal
	tempDir := "./uploads/" + host
	os.MkdirAll(tempDir, os.ModePerm)
	filePath := filepath.Join(tempDir, handler.Filename)
	out, err := os.Create(filePath)
	if err != nil {
		http.Error(w, "Error al guardar archivo", http.StatusInternalServerError)
		return
	}
	defer out.Close()
	io.Copy(out, file)

	// Simular aprovisionamiento de VM
	//obtener ip
	ip := "192.168.1.100" // de prueba
	//obtener url
	url := fmt.Sprintf("http://%s/", ip) // de prueba
	//obtener fecha
	fecha := time.Now().Format("2006-01-02 15:04:05") //de prueba

	// Solicitar maquina virtual por host y mandar el .zip con SCP Y SSH

	// Responder al frontend
	instancia := Instancia{
		Host:  host,
		IP:    ip,
		URL:   url,
		Fecha: fecha,
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"exito": true,
		"host":  instancia.Host,
		"ip":    instancia.IP,
		"url":   instancia.URL,
		"fecha": instancia.Fecha,
	})
}

func eliminarHandler(w http.ResponseWriter, r *http.Request) {

	//script para eliminar maquina virtual o solo .zip?
}

func main() {

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "templates/interfaz_principal.html")
	})

	http.HandleFunc("/crear", solicitaciónHnandler)
	http.HandleFunc("/publicar", publicarHandler)
	http.Handle("/uploads/", http.StripPrefix("/uploads/", http.FileServer(http.Dir("./uploads"))))
	http.HandleFunc("/eliminar", eliminarHandler)

	fmt.Println("Servidor escuchando en http://localhost:8080")
	http.ListenAndServe(":8080", nil)
}
