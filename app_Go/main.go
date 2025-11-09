package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

type Instancia struct {
	Host  string `json:"host"`
	IP    string `json:"ip"`
	URL   string `json:"url"`
	Fecha string `json:"fecha"`
}

func despliegue(zipPath, ip string) {

	// Si usas Git Bash o WSL
	cmd := exec.Command("bash", "./deploy.sh", zipPath, ip)

	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Println("Error ejecutando script:", err)
	}
	fmt.Println(string(output))
}

func configuracionred(ip, ipstatic string) {

	// Si usas Git Bash o WSL
	cmd := exec.Command("bash", "./configurar_red.sh", ip, ipstatic)

	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Println("Error ejecutando script:", err)
	}
	fmt.Println(string(output))
}

func solicitaciónHnandler(w http.ResponseWriter, r *http.Request) {

	if r.Method == http.MethodPost {
		host := r.FormValue("host")

		if host == "" {
			//necesito veriifcar que no haya otro hostname con el mismo nombre
			http.Redirect(w, r, "/", http.StatusSeeOther)
			return
		}

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
	fecha := time.Now().Format("2006-01-02 15:04:05")

	// Solicitar maquina virtual por host y obtener el ip
	cmd := exec.Command("python", "Scripts\\library\\New_VM.py", host)
	var out_bytes bytes.Buffer
	cmd.Stdout = &out_bytes // capturamos errores
	cmd.Stderr = &out_bytes
	error := cmd.Run()
	if error != nil {
		fmt.Println("error creando maquina virtual", err)
	}
	fmt.Println(" Salida del script Python:\n", out_bytes.String())
	time.Sleep(30000000000)

	// Obtener la salida y limpiar espacios
	raw := out_bytes.String()
	raw = strings.TrimSpace(raw)

	// Buscar la primera IP válida en la salida
	re := regexp.MustCompile(`\b\d{1,3}(\.\d{1,3}){3}\b`)
	ip := re.FindString(raw)

	if ip != "" {
		fmt.Println(" IP detectada:", ip)
	} else {
		fmt.Println(" No se detectó una IP válida. Salida:", raw)
	}

	fmt.Println(ip)
	despliegue(filePath, ip)

	var ipstatic = "192.168.222.3"
	configuracionred(ip, ipstatic) //aca necesito la ip estatica

	//aca necesito el diminio por el que vamos a acceder
	url := fmt.Sprintf("http://%s/", ipstatic) //cambia ipstatic por el nombre de dominio

	// Responder al frontend
	instancia := Instancia{
		Host:  host,
		IP:    ipstatic,
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
	// Leer JSON del cuerpo
	var data struct {
		Host string `json:"host"` // nombre de la VM
	}
	if err := json.NewDecoder(r.Body).Decode(&data); err != nil {
		http.Error(w, "Error al leer datos", http.StatusBadRequest)
		return
	}

	// Ejecutar script con el nombre de la VM como argumento
	cmd := exec.Command("cmd", "/C", "Scripts\\library\\Remove_VM.py", data.Host)
	var out_bytes bytes.Buffer
	cmd.Stdout = &out_bytes
	cmd.Stderr = &out_bytes

	err := cmd.Run()
	if err != nil {
		log.Println(" Error borrando máquina:", out_bytes.String())
		http.Error(w, "Error eliminando VM", http.StatusInternalServerError)
		return
	}

	log.Println("VM eliminada:", out_bytes.String())
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ok"}`))
}

func main() {

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "templates/interfaz_principal.html")
	})

	http.HandleFunc("/crear", solicitaciónHnandler)
	http.HandleFunc("/publicar", publicarHandler)
	http.Handle("/uploads/", http.StripPrefix("/uploads/", http.FileServer(http.Dir("./uploads"))))
	http.HandleFunc("/eliminar", eliminarHandler)

	fmt.Println("Servidor escuchando en http://localhost:8088")
	http.ListenAndServe(":8088", nil)

}
