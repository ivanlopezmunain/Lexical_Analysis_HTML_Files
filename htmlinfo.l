%{

//Ivan Lopez de Munain Quintana

#include <stdio.h>
#include <string.h>
#include <ctype.h>

// Declaramos e inicializamos contadores de línea y columna
int	nlin = 1;
int	ncol = 1;

//declaraciones variables para realizar analisis estadisticos de etiquetas
int 	numEtiquetas[100]={0};
char 	*etiquetas[100];
int 	contador=0;

//arrays y contadores para obtener las URLs de A, SCRIPT y LINK
char	*arrayEnlaces[5000];
int 	contadorEnlaces=0;

//arrays y contadores para obtener las URLs de IMG
char	*arrayImagenes[10000];
int 	contadorImagenes=0;

//string  para obtener la URL de BASE y flag para saber existencia de enlace absoluto o no
char	*urlBase[1];
int 	Absoluto=0;

// Declaramos e inicializamos lista de ficheros de entrada
int	nficherosEntrada = 0;
int	nficheroActual = 0;
char	**ficherosEntrada = NULL;
char	*inFileName = NULL ;



// DECLARACIONES DE FUNCIONES
void IgnoraComentarioMultiLinea(int *, int *);
void procesamientoEtiquetas();
void procesamientoLINKS();
void procesamientoIMAGES();
int procesamientoPalabras(char *, char *);
void procesamientoBASE();

//FINAL SECCIÓN DECLARACIONES //

%}

SPACE	[ \t]+

IDENT [a-zA-Z]+

ETIQUETA \<{IDENT}
CIERREETIQUETA \<\/{IDENT}\>

TITLE \<(?i:title)\>
CIERRETITLE <\/(?i:title)\>

LINKS	\<((?i:a)|(?i:link))
HREF	(?i:href)

LINKS2 \<(?i:script)
SRC	(?i:src)

IMG	\<(?i:img)
LONGDESC (?i:longdesc) 
USEMAP	 (?i:usemap)

BASE	\<(?i:base)

%%


"<!--"							IgnoraComentarioMultiLinea(&nlin,&ncol);

{SPACE}*{IDENT}({SPACE}{IDENT})*/{CIERRETITLE}		printf("TITLE: %s\n",yytext);

{ETIQUETA}[^>]						procesamientoEtiquetas();

{LINKS}.*{HREF}.+/>					{		
							procesamientoLINKS();
							REJECT;}

{LINKS2}.*{SRC}.+/>					{procesamientoLINKS();
							REJECT;}

{IMG}.*{SRC}.+/>					{procesamientoIMAGES();
							REJECT;}

{IMG}.*{LONGDESC}.+/>					{procesamientoIMAGES();
							REJECT;}

{IMG}.*{USEMAP}.+/>					{procesamientoIMAGES();
							REJECT;}


{BASE}.*{HREF}.+/>					{procesamientoBASE();
							REJECT;}


{SPACE}							{ ncol += strlen(yytext) ; }

.							{ ncol++; }
\n							{ nlin++; ncol=1; }


%%

/*
 * PROGRAMA PRINCIPAL: PUNTO DE ENTRADA main()
 *
 * Permite especificar lista de ficheros de entrada en línea de órdenes
 * Gestiona, junto a yywrap() el cambio de fichero y la cuenta de número
 * de línea y columna.
 *
 *Se imprime la primera linea del fichero FILE
 */

int main(int na, char *av[]) {

	int	i;
	
	//inicializacion del vector que contiene las distintas etiquetas
	for(int j=0;j<=50;j++){
		etiquetas[j]="vacio";
	}
	
	nficherosEntrada = na - 1 ;
	ficherosEntrada = (char **) malloc((nficherosEntrada) * sizeof(char *)) ;
 	for (int i=1 ; i<na ; i++) {
		//obtención del file con el que se aplica el analizador lexico
		printf("FILE: %s\n",av[i]); 
		ficherosEntrada[i-1] = strdup(av[i]) ; 
	}

	nficheroActual = 0 ;
	if (nficherosEntrada > 0) {
	   // Si se han especificado ficheros, abre el primero
	   inFileName = ficherosEntrada[nficheroActual++] ;
	   yyin = fopen(inFileName, "r");
	}

	// LLAMADA AL SCANNER (Una vez para todos los ficheros)
	while (i=yylex()) ;

}

/*
 * Funcion: yywrap
 *
 * Llamada por yylex() cada vez que se termina la entrada.
 * RETURN:
 *	0:	Sigue procesando
 *	1:	No proceses más
 *
 *En caso de que no se procese mas ficheros se obtiene el titulo y los resumenes estadisticos
 *para las etiquetas y urls.
 *
 */

int yywrap(void) {

    // Si proviene de un fichero abierto por nosotros, lo cerramos
    if (inFileName){
    	fclose(yyin) ;

	//=============== RESUMEN PARA ETIQUETAS ========================

	//ordenamiento alfabetico de las etiquetas almacenadas
	char *tmp;
	int aux;
	for(int i=0;i<contador; i++) {
        	for(int j=0; j<contador; j++) {
            		if(strcmp(etiquetas[i], etiquetas[j]) < 0) {
                		tmp = etiquetas[i];
				aux = numEtiquetas[i];
                		etiquetas[i] = etiquetas[j];
				numEtiquetas[i] = numEtiquetas[j];
                		etiquetas[j] = tmp;
				numEtiquetas[j] = aux;
            		}
        	}
    	}

	//conversion a minusculas
	for(int i=0;i<contador;i++){
		int w=0;
		while(etiquetas[i][w] ) {
			etiquetas[i][w]=tolower(etiquetas[i][w]);
      			w++;
   		}
	}

	//impresion del resumen estadistico de etiquetas
	printf("TAGSTATS:\n");
    	for(int i=0;i<contador;i++){
		//NOS ASEGURAMOS QUE NO HAYA ETIQUETAS !DOCTYPE
		if(strcmp(etiquetas[i],"!doctype")!=0){
			printf("\t%s\t%d\n",etiquetas[i],(numEtiquetas[i]+1));
		}
	}

	
	//======================== LINKS PARA A, SCRIPT Y LINK ==============================


	//impresion de los links procedentes de etiquetas A, SCRIPT y LINK
	printf("LINKS: \n");
	int posicion;
	int posicion2;
	int posicion3;
	char *final[contadorEnlaces];

	/*procesamiento de URL teniendo en cuenta que 
		-la etiqueta a y link posee el atributo href
		-la etiqueta script posee el atributo src
		
	hago un procesado de cadenas teniendo en cuenta el nombre del atributo en cuestion
	y que la url deseada se encuentra entre comillas

	Uso de la funcion memcpy para eliminar los caracteres que se encuentren al inicio de la palabra (ej: href=, src=...)
	procesamientoPalabra(char*, char) nos devuelve el indice de la primera ocurrencia de un caracter en un string, cero en caso contario
		-este procedimiento nos va a ayudar para localizar las comillas dle inicio y final de la url y quedarnos con lo del medio
	*/

	int posAux;
	for(int i=0;i<contadorEnlaces;i++){
		if(procesamientoPalabras(arrayEnlaces[i],"href")!=0){
			posicion = procesamientoPalabras(arrayEnlaces[i],"href");
			memcpy(arrayEnlaces[i],arrayEnlaces[i]+posicion,strlen(arrayEnlaces[i])-posicion+1);
			posicion2 = procesamientoPalabras(arrayEnlaces[i],"\"");
			memcpy(arrayEnlaces[i],arrayEnlaces[i]+posicion2+1,strlen(arrayEnlaces[i])-posicion2+1);
			posAux = procesamientoPalabras(arrayEnlaces[i]," ");
			
			posicion3 = procesamientoPalabras(arrayEnlaces[i],"\"");
		}else if(procesamientoPalabras(arrayEnlaces[i],"src")!=0){
			posicion = procesamientoPalabras(arrayEnlaces[i],"src");
			memcpy(arrayEnlaces[i],arrayEnlaces[i]+posicion,strlen(arrayEnlaces[i])-posicion+1);
			posicion2 = procesamientoPalabras(arrayEnlaces[i],"\"");
			memcpy(arrayEnlaces[i],arrayEnlaces[i]+posicion2+1,strlen(arrayEnlaces[i])-posicion2+1);
			posAux = procesamientoPalabras(arrayEnlaces[i]," ");
			posicion3 = procesamientoPalabras(arrayEnlaces[i],"\"");
		}
		final[i]=(char *)malloc(posicion3+1);
		
		//compruebo que las primeras comillas aparezcan antes que el primer espacio
		if(posicion3<posAux){
			for(int j=0;j<(posicion3);j++){
				final[i][j]=arrayEnlaces[i][j];
			}
		}
	}
	
	//el siguiente codigo es simplemente para borrar aquellas urls que aparezcan repetidas
	//reservado de memoria para el ultimo array de url sin repeticiones
	char *final2[contadorEnlaces];
	for(int i=0;i<contadorEnlaces;i++){
		final2[i]=(char *)malloc(strlen(final[i]));
	}

	strcpy(final2[0],final[0]);
	int cont=1;
	for(int i=1;i<contadorEnlaces;i++){
		int flag=0;
		for(int j=0;j<contadorEnlaces;j++){
			if(strcmp(final[i],final2[j])==0){
				j=contadorEnlaces;
				flag=1;
			}
		}
		if(flag==0){
			strcpy(final2[cont],final[i]);
			cont++;
		}
	}
	
	
	// ============== URL DE BASE =========================================


	//depuracion de la url absoluta de la etiqueta base en caso de que existiese
	//almacenamiento en urlAbs
	char *urlAbs[1];
	if(Absoluto==1){
		posicion = procesamientoPalabras(urlBase[0],"href");
		memcpy(urlBase[0],urlBase[0]+posicion,strlen(urlBase[0])-posicion+1);
		posicion2 = procesamientoPalabras(urlBase[0],"\"");
		memcpy(urlBase[0],urlBase[0]+posicion2+1,strlen(urlBase[0])-posicion2+1);
		posicion3 = procesamientoPalabras(urlBase[0],"\"");
		urlAbs[0]=(char *)malloc(posicion3+1);
		for(int j=0;j<(posicion3);j++){
			urlAbs[0][j]=urlBase[0][j];
			}

	}

	//finalmente se imprime el listado de urls de A SCRIPT y LINK del fichero
	for(int w=0;w<cont;w++){
		if(Absoluto==1){
			printf("\t%s / %s\n",urlAbs[0],final2[w]);
		}else{
			printf("\t%s\n",final2[w]);

		}
	}


	//========================= LINKS PARA IMG =========================


	/*procesamiento de URL teniendo en cuenta que 
		-la etiqueta img  posee los atributos src, usemap y longdesc que puedan contener url
		
	hago un procesado de cadenas teniendo en cuenta el nombre del atributo en cuestion
	y que la url deseada se encuentra entre comillas

	Uso de la funcion memcpy para eliminar los caracteres que se encuentren al inicio de la palabra (ej: usemap=, src=...)
	procesamientoPalabra(char*, char) nos devuelve el indice de la primera ocurrencia de un caracter en un string, cero en caso contario
		-este procedimiento nos va a ayudar para localizar las comillas dle inicio y final de la url y quedarnos con lo del medio
	*/

	printf("IMAGES: \n");
	char *finalImagen[contadorImagenes];
	for(int i=0;i<contadorImagenes;i++){
		if(procesamientoPalabras(arrayImagenes[i],"src")!=0){
			posicion = procesamientoPalabras(arrayImagenes[i],"src");
			memcpy(arrayImagenes[i],arrayImagenes[i]+posicion,strlen(arrayImagenes[i])-posicion+1);
			posicion2 = procesamientoPalabras(arrayImagenes[i],"\"");
			memcpy(arrayImagenes[i],arrayImagenes[i]+posicion2+1,strlen(arrayImagenes[i])-posicion2+1);
			posAux = procesamientoPalabras(arrayImagenes[i]," ");
			posicion3 = procesamientoPalabras(arrayImagenes[i],"\"");
		}else if(procesamientoPalabras(arrayImagenes[i],"longdesc")!=0){
			posicion = procesamientoPalabras(arrayImagenes[i],"longdesc");
			memcpy(arrayImagenes[i],arrayImagenes[i]+posicion,strlen(arrayImagenes[i])-posicion+1);
			posicion2 = procesamientoPalabras(arrayImagenes[i],"\"");
			memcpy(arrayImagenes[i],arrayImagenes[i]+posicion2+1,strlen(arrayImagenes[i])-posicion2+1);
			posAux = procesamientoPalabras(arrayImagenes[i]," ");
			posicion3 = procesamientoPalabras(arrayImagenes[i],"\"");
		}else if(procesamientoPalabras(arrayImagenes[i],"usemap")!=0){
			posicion = procesamientoPalabras(arrayImagenes[i],"usemap");
			memcpy(arrayImagenes[i],arrayImagenes[i]+posicion,strlen(arrayImagenes[i])-posicion+1);
			posicion2 = procesamientoPalabras(arrayImagenes[i],"\"");
			memcpy(arrayImagenes[i],arrayImagenes[i]+posicion2+1,strlen(arrayImagenes[i])-posicion2+1);
			posAux = procesamientoPalabras(arrayImagenes[i]," ");
			posicion3 = procesamientoPalabras(arrayImagenes[i],"\"");
		}
		finalImagen[i]=(char *)malloc(posicion3+1);
		
		//compruebo que las primeras comillas aparezcan antes que el primer espacio
		if(posicion3<posAux){
			for(int j=0;j<(posicion3);j++){
				finalImagen[i][j]=arrayImagenes[i][j];
			}
		}
	}

	//el siguiente codigo es simplemente para borrar aquellas urls que aparezcan repetidas
	//reservado de memoria para el ultimo array de url sin repeticiones
	char *finalImagen2[contadorImagenes];
	for(int i=0;i<contadorImagenes;i++){
		finalImagen2[i]=(char *)malloc(strlen(finalImagen[i]));
	}

	strcpy(finalImagen2[0],finalImagen[0]);
	cont=1;
	for(int i=1;i<contadorImagenes;i++){
		int flag=0;
		for(int j=0;j<contadorImagenes;j++){
			if(strcmp(finalImagen[i],finalImagen2[j])==0){
				j=contadorImagenes;
				flag=1;
			}
		}
		if(flag==0){
			strcpy(finalImagen2[cont],finalImagen[i]);
			cont++;
		}
	}

	//finalmente se imprime el listado de urls de IMG del fichero
	for(int w=0;w<cont;w++){
		if(Absoluto==1){
			printf("\t%s / %s\n",urlAbs[0],finalImagen2[w]);
		}else{
			printf("\t%s\n",finalImagen2[w]);
		}
	}

}

    // No hay más ficheros
    if (nficheroActual >= nficherosEntrada)return 1;


    // Abre el siguiente fichero
    // DBG: fprintf(stdout, "______Abro[%s]\n", avg[nfa]), fflush(stdout);
	inFileName = ficherosEntrada[nficheroActual++] ;
	yyin = fopen(inFileName, "r");
    return 0;
}

/*
 * Procesamos comentarios multilinea sin expresiones regulares
 */
void
IgnoraComentarioMultiLinea(int *nl, int *nc)
{
  int t, c;
  int done = 0;

  // DBG:
#ifdef	VERBOSE
  fprintf(stderr, "___DBG: Procesando comentario (%d, %d)-{", *nl, *nc);
#endif
  while(!done) {
    switch(t=input())
    {
      /* EOF: Bad comment */
      case EOF:
        fprintf(stderr, "___ERROR: unclosed comment, expect */\n");
        done = 1 ;
      break;

      case '-':
    	switch(t=input())
    	{
      	/* EOF: Bad comment */
      	case EOF:
        	fprintf(stderr, "___ERROR: unclosed comment, expect */\n");
        	done = 1 ;
      	break;

      	case '-':
        	if((c = input()) == '>') { *nc = *nc + 2 ; done = 1; }
		else			 { *nc = *nc + 1 ; unput(c); }
#ifdef	VERBOSE
        	if (!done) { fputc(t, stderr); fputc(c, stderr) ; }
#endif
      	break;

      	default:
		if (t=='\n') { *nl = *nl + 1 ; *nc = 1 ;}
		else	     { *nc = *nc + 1 ; }
#ifdef	VERBOSE
        	fputc(t, stderr);
#endif
      	break;
    }
  }
 }
#ifdef	VERBOSE
  fprintf(stderr, "}-(%d, %d)\n", *nl, *nc);
#endif
}

/*
*Almacenamiento de la etiqueta entera(sin depurar) en etiquetas
*
*/
void procesamientoEtiquetas(){
	int tag=0;
	int i;
	char *etiq;
	etiq=(char*)malloc(1+strlen(yytext)*sizeof(char *));
	memcpy(etiq,yytext+1,sizeof(yytext));
	for(i=0;i<=contador;i++){
		if(strcmp(etiq,etiquetas[i])==0){
			numEtiquetas[i]++;
			tag=1;
		}
	}
	if(tag==0){
		etiquetas[contador]=etiq;
		contador++;
	}
}

/*
*Almacenamiento de las urls de a, script y link  entera(sin depurar) en arrayEnlaces
*
*/
void procesamientoLINKS(){
	char *links;
	int indice;
	int tag=1;
	links=(char*)malloc(1+strlen(yytext));
	strcpy(links,yytext);
	arrayEnlaces[contadorEnlaces]=links;
	contadorEnlaces++;
}


/*
*Almacenamiento de las url de imagenes entera(sin depurar) en arrayImagenes
*
*/
void procesamientoIMAGES(){
	char *img;
	img=(char*)malloc(1+strlen(yytext));
	strcpy(img,yytext);
	arrayImagenes[contadorImagenes]=img;
	contadorImagenes++;
}

/*
*Funcion que devuelve la posicion donde se encuentra una subcadena dentro de una cadena
*/
int procesamientoPalabras(char palabra[], char subcadena[]){

	int posicion;
	if(strstr(palabra,subcadena)!=NULL){
		posicion = strstr(palabra,subcadena)-palabra;
		return posicion;
	}else{
		return 0;
	}
}

/*
*Procedimiento que obtiene la url(sin depurar) del atributo BASE y actualiza la variable global Absoluto
*/
void procesamientoBASE(){

	char *base;
	Absoluto=1;
	base=(char*)malloc(1+strlen(yytext));
	strcpy(base,yytext);
	urlBase[0]=base;
}

